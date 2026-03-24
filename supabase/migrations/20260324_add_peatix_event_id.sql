-- peetix_events テーブルに peatix_event_id を追加（スクレイピング時の重複排除用）
ALTER TABLE peetix_events
  ADD COLUMN IF NOT EXISTS peatix_event_id TEXT UNIQUE;

-- 終了済みイベントも含めて全件取得できるようにステータス自動更新
-- GitHub Actions からの UPSERT 用に service_role での INSERT/UPDATE を許可
CREATE POLICY "Service role can manage events"
  ON peetix_events FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- テストデータを削除（今後は Peatix から自動取得）
DELETE FROM peetix_events WHERE peatix_event_id IS NULL;
