-- HeroEgg Supabase Schema Setup
-- Run this in your Supabase SQL Editor

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- 1. profiles テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  display_name TEXT,
  phone TEXT,
  avatar_url TEXT,
  account_type TEXT DEFAULT 'general',
  member_rank TEXT DEFAULT 'regular',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 新規ユーザー登録時にプロフィールを自動作成するトリガー
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 2. egg_facilities テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS egg_facilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  address TEXT DEFAULT '',
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  image_url TEXT,
  location GEOGRAPHY(POINT, 4326),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- location カラム自動設定トリガー
CREATE OR REPLACE FUNCTION public.set_facility_location()
RETURNS TRIGGER AS $$
BEGIN
  NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_facility_location_trigger
  BEFORE INSERT OR UPDATE ON egg_facilities
  FOR EACH ROW EXECUTE FUNCTION public.set_facility_location();

CREATE TRIGGER egg_facilities_updated_at
  BEFORE UPDATE ON egg_facilities
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- 空間インデックス
CREATE INDEX IF NOT EXISTS idx_egg_facilities_location ON egg_facilities USING GIST (location);

-- ============================================================
-- 3. peetix_events テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS peetix_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  event_date TIMESTAMPTZ NOT NULL,
  location_name TEXT DEFAULT '',
  peetix_url TEXT,
  image_url TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'completed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER peetix_events_updated_at
  BEFORE UPDATE ON peetix_events
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 4. inquiries テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  inquiry_type TEXT NOT NULL CHECK (inquiry_type IN ('general', 'partner', 'bug', 'feature')),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT DEFAULT 'new' CHECK (status IN ('new', 'in_progress', 'resolved', 'closed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER inquiries_updated_at
  BEFORE UPDATE ON inquiries
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 5. check_ins テーブル (Phase 1 はスキーマのみ)
-- ============================================================
CREATE TABLE IF NOT EXISTS check_ins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  facility_id UUID NOT NULL REFERENCES egg_facilities(id) ON DELETE CASCADE,
  checked_in_at TIMESTAMPTZ DEFAULT NOW(),
  checked_out_at TIMESTAMPTZ
);

-- ============================================================
-- RPC: 近隣施設検索
-- ============================================================
CREATE OR REPLACE FUNCTION get_nearby_facilities(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  radius_meters DOUBLE PRECISION DEFAULT 50000
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  image_url TEXT,
  distance DOUBLE PRECISION
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    f.id,
    f.name,
    f.description,
    f.address,
    f.latitude,
    f.longitude,
    f.image_url,
    ST_Distance(
      f.location,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
    ) AS distance
  FROM egg_facilities f
  WHERE ST_DWithin(
    f.location,
    ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
    radius_meters
  )
  ORDER BY distance;
$$;

-- ============================================================
-- Row Level Security (RLS)
-- ============================================================

-- profiles RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- egg_facilities RLS (認証済みユーザーが読み取り可能)
ALTER TABLE egg_facilities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view facilities"
  ON egg_facilities FOR SELECT
  TO authenticated
  USING (true);

-- peetix_events RLS (認証済みユーザーが読み取り可能)
ALTER TABLE peetix_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view events"
  ON peetix_events FOR SELECT
  TO authenticated
  USING (true);

-- inquiries RLS
ALTER TABLE inquiries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert inquiries"
  ON inquiries FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can view own inquiries"
  ON inquiries FOR SELECT
  USING (auth.uid() = user_id);

-- check_ins RLS
ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own check_ins"
  ON check_ins FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own check_ins"
  ON check_ins FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own check_ins"
  ON check_ins FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================
-- テストデータ
-- ============================================================
INSERT INTO egg_facilities (name, description, address, latitude, longitude, image_url)
VALUES
  ('Egg 渋谷', '渋谷駅徒歩5分のコワーキングスペース。高速Wi-Fi、会議室完備。', '東京都渋谷区渋谷1-1-1', 35.6580, 139.7016, NULL),
  ('Egg 新宿', '新宿三丁目駅直結。24時間利用可能なワークスペース。', '東京都新宿区新宿3-1-1', 35.6896, 139.7006, NULL),
  ('Egg 六本木', '六本木ヒルズ近く。クリエイター向けのコミュニティスペース。', '東京都港区六本木6-1-1', 35.6604, 139.7292, NULL),
  ('Egg 品川', '品川駅港南口すぐ。ビジネスミーティングに最適。', '東京都港区港南2-1-1', 35.6284, 139.7387, NULL),
  ('Egg 池袋', '池袋駅東口徒歩3分。広々としたオープンスペース。', '東京都豊島区東池袋1-1-1', 35.7295, 139.7109, NULL);

INSERT INTO peetix_events (title, description, event_date, location_name, peetix_url, status)
VALUES
  ('HeroEgg Community Meetup #1', '第1回HeroEggコミュニティミートアップ。起業家とクリエイターの交流会。', '2026-04-15 19:00:00+09', 'Egg 渋谷', 'https://peetix.com/event/example1', 'active'),
  ('スタートアップピッチナイト', 'スタートアップがピッチする夜のイベント。投資家との出会いの場。', '2026-04-22 18:30:00+09', 'Egg 六本木', 'https://peetix.com/event/example2', 'active'),
  ('AIワークショップ for Beginners', 'AIの基礎を学ぶハンズオンワークショップ。初心者歓迎。', '2026-05-10 14:00:00+09', 'Egg 新宿', 'https://peetix.com/event/example3', 'active'),
  ('共創パートナーDay', 'HeroEggの共創パートナーとの交流イベント。新しいコラボレーションの機会。', '2026-05-20 15:00:00+09', 'Egg 品川', 'https://peetix.com/event/example4', 'active');
