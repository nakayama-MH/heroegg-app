/**
 * Peatix → Supabase イベント同期スクリプト
 *
 * Playwright で https://meta-heroes.peatix.com/ を開き、
 * イベント一覧をスクレイピングして Supabase に UPSERT する。
 *
 * 使い方:
 *   npx tsx scripts/sync-peatix.ts
 *
 * 環境変数:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 */

import { chromium, type Page } from "playwright";
import { createClient } from "@supabase/supabase-js";

const PEATIX_URL = "https://meta-heroes.peatix.com/";

interface PeatixEvent {
  peatix_event_id: string;
  title: string;
  description: string;
  event_date: string;
  location_name: string;
  peatix_url: string;
  image_url: string | null;
  status: "active" | "cancelled" | "completed";
}

// ---------------------------------------------------------------------------
// 1. スクレイピング
// ---------------------------------------------------------------------------

async function scrapePeatixEvents(): Promise<PeatixEvent[]> {
  console.log("🔍 Peatix ページを開きます...");

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    locale: "ja-JP",
    userAgent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  });
  const page = await context.newPage();

  try {
    await page.goto(PEATIX_URL, { waitUntil: "networkidle", timeout: 30000 });

    // イベントリストが描画されるまで待機
    await page.waitForSelector('[class*="event"], a[href*="/event/"]', {
      timeout: 15000,
    }).catch(() => {
      console.log("⚠️  イベント要素の検出にフォールバックします");
    });

    // 少し待ってJSレンダリング完了を確保
    await page.waitForTimeout(3000);

    const events = await extractEvents(page);
    console.log(`✅ ${events.length} 件のイベントを取得しました`);

    // 各イベントの詳細ページから追加情報を取得
    const detailedEvents: PeatixEvent[] = [];
    for (const event of events) {
      try {
        const detailed = await scrapeEventDetail(page, event);
        detailedEvents.push(detailed);
        console.log(`  📄 ${detailed.title}`);
      } catch (e) {
        console.error(`  ❌ 詳細取得失敗: ${event.peatix_url}`, e);
        detailedEvents.push(event);
      }
    }

    return detailedEvents;
  } finally {
    await browser.close();
  }
}

async function extractEvents(page: Page): Promise<PeatixEvent[]> {
  return page.evaluate(() => {
    const events: Array<{
      peatix_event_id: string;
      title: string;
      description: string;
      event_date: string;
      location_name: string;
      peatix_url: string;
      image_url: string | null;
      status: "active" | "cancelled" | "completed";
    }> = [];

    // Peatix のイベントリンクを探す（複数のセレクターで対応）
    const links = document.querySelectorAll<HTMLAnchorElement>(
      'a[href*="/event/"]'
    );

    const seen = new Set<string>();

    for (const link of links) {
      const href = link.href;
      // /event/{数字} パターンを抽出
      const match = href.match(/\/event\/(\d+)/);
      if (!match) continue;

      const eventId = match[1];
      if (seen.has(eventId)) continue;
      seen.add(eventId);

      // リンク内またはその親要素からテキストを取得
      const container = link.closest('[class*="event"]') || link;
      const title =
        container.querySelector("h2, h3, [class*='title'], [class*='name']")
          ?.textContent?.trim() ||
        link.textContent?.trim() ||
        "";

      if (!title) continue;

      // 画像を探す
      const img = container.querySelector<HTMLImageElement>("img");
      const imageUrl = img?.src || null;

      events.push({
        peatix_event_id: eventId,
        title,
        description: "",
        event_date: new Date().toISOString(), // 詳細ページで上書き
        location_name: "",
        peatix_url: `https://peatix.com/event/${eventId}`,
        image_url: imageUrl,
        status: "active",
      });
    }

    return events;
  });
}

async function scrapeEventDetail(
  page: Page,
  event: PeatixEvent
): Promise<PeatixEvent> {
  const detailPage = await page.context().newPage();

  try {
    await detailPage.goto(event.peatix_url, {
      waitUntil: "networkidle",
      timeout: 20000,
    });

    await detailPage.waitForTimeout(2000);

    const detail = await detailPage.evaluate(() => {
      // JSON-LD から構造化データを取得（最も信頼性が高い）
      const jsonLd = document.querySelector(
        'script[type="application/ld+json"]'
      );
      if (jsonLd) {
        try {
          const data = JSON.parse(jsonLd.textContent || "");
          if (data["@type"] === "Event" || data.startDate) {
            return {
              title: data.name || "",
              description: data.description || "",
              event_date: data.startDate || "",
              location_name:
                data.location?.name ||
                data.location?.address?.addressLocality ||
                "",
              image_url: data.image || null,
            };
          }
        } catch {
          // パース失敗、DOMから取得にフォールバック
        }
      }

      // DOM から取得
      const title =
        document.querySelector("h1, [class*='event-name'], [class*='title']")
          ?.textContent?.trim() || "";

      const description =
        document.querySelector(
          "[class*='description'], [class*='detail'], [class*='body']"
        )?.textContent?.trim() || "";

      // OGP メタタグから情報取得
      const ogImage =
        document
          .querySelector('meta[property="og:image"]')
          ?.getAttribute("content") || null;

      // 日時情報を探す
      const dateEl = document.querySelector(
        "[class*='date'], [class*='time'], time"
      );
      const dateText = dateEl?.getAttribute("datetime") ||
        dateEl?.textContent?.trim() || "";

      // 場所情報
      const locationEl = document.querySelector(
        "[class*='venue'], [class*='location'], [class*='place']"
      );
      const locationName = locationEl?.textContent?.trim() || "";

      return {
        title,
        description: description.substring(0, 500),
        event_date: dateText,
        location_name: locationName,
        image_url: ogImage,
      };
    });

    return {
      ...event,
      title: detail.title || event.title,
      description: detail.description || event.description,
      event_date: parseEventDate(detail.event_date) || event.event_date,
      location_name: detail.location_name || event.location_name,
      image_url: detail.image_url || event.image_url,
    };
  } finally {
    await detailPage.close();
  }
}

function parseEventDate(dateStr: string): string | null {
  if (!dateStr) return null;

  // ISO 8601 形式ならそのまま
  const iso = Date.parse(dateStr);
  if (!isNaN(iso)) {
    return new Date(iso).toISOString();
  }

  // 日本語の日付パターン: "2026年4月15日 19:00" など
  const jaMatch = dateStr.match(
    /(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日\s*(\d{1,2}):(\d{2})/
  );
  if (jaMatch) {
    const [, year, month, day, hour, min] = jaMatch;
    return new Date(
      Number(year),
      Number(month) - 1,
      Number(day),
      Number(hour),
      Number(min)
    ).toISOString();
  }

  return null;
}

// ---------------------------------------------------------------------------
// 2. Supabase UPSERT
// ---------------------------------------------------------------------------

async function upsertToSupabase(events: PeatixEvent[]): Promise<void> {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    throw new Error(
      "SUPABASE_URL と SUPABASE_SERVICE_ROLE_KEY を設定してください"
    );
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log(`\n📤 ${events.length} 件を Supabase に同期します...`);

  for (const event of events) {
    const { error } = await supabase.from("peetix_events").upsert(
      {
        peatix_event_id: event.peatix_event_id,
        title: event.title,
        description: event.description,
        event_date: event.event_date,
        location_name: event.location_name,
        peetix_url: event.peatix_url,
        image_url: event.image_url,
        status: event.status,
      },
      { onConflict: "peatix_event_id" }
    );

    if (error) {
      console.error(`  ❌ UPSERT 失敗 [${event.title}]:`, error.message);
    } else {
      console.log(`  ✅ ${event.title}`);
    }
  }

  // 過去イベントのステータスを自動更新
  const { error: updateError } = await supabase
    .from("peetix_events")
    .update({ status: "completed" })
    .lt("event_date", new Date().toISOString())
    .eq("status", "active");

  if (updateError) {
    console.error("  ❌ ステータス更新失敗:", updateError.message);
  } else {
    console.log("  ✅ 過去イベントのステータスを更新しました");
  }
}

// ---------------------------------------------------------------------------
// 3. メイン
// ---------------------------------------------------------------------------

async function main() {
  console.log("=== Peatix → Supabase 同期開始 ===\n");

  try {
    const events = await scrapePeatixEvents();

    if (events.length === 0) {
      console.log("⚠️  イベントが見つかりませんでした");
      return;
    }

    await upsertToSupabase(events);
    console.log("\n=== 同期完了 ===");
  } catch (error) {
    console.error("❌ 同期失敗:", error);
    process.exit(1);
  }
}

main();
