-- イベント管理: Peatix依存を除去し、管理者がアプリ内でCRUD可能にする

-- created_by カラム追加（イベント作成者の追跡）
ALTER TABLE peetix_events
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- 管理者用ヘルパー関数（profilesテーブルのroleを参照）
CREATE OR REPLACE FUNCTION public.is_admin_or_staff()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role IN ('admin', 'staff')
  );
$$;

-- 管理者/スタッフはイベントを作成できる
CREATE POLICY "Admin/staff can insert events"
  ON peetix_events FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin_or_staff());

-- 管理者/スタッフはイベントを更新できる
CREATE POLICY "Admin/staff can update events"
  ON peetix_events FOR UPDATE
  TO authenticated
  USING (public.is_admin_or_staff())
  WITH CHECK (public.is_admin_or_staff());

-- 管理者/スタッフはイベントを削除できる
CREATE POLICY "Admin/staff can delete events"
  ON peetix_events FOR DELETE
  TO authenticated
  USING (public.is_admin_or_staff());
