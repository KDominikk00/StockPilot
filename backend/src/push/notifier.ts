import { db } from "../db/client";
import { isConfigured, sendPush } from "./apns";

interface SubscriberRow {
  device_token: string;
}

function subscribersForTicker(ticker: string): string[] {
  const rows = db
    .prepare(
      `SELECT ds.device_token
       FROM device_subscription_tickers dst
       JOIN device_subscriptions ds ON ds.id = dst.device_subscription_id
       WHERE dst.ticker = ?`
    )
    .all(ticker) as unknown as SubscriberRow[];
  return rows.map((r) => r.device_token);
}

export async function notifyNewAnnouncement(params: {
  ticker: string;
  title: string;
  url: string;
}): Promise<{ notified: number; skippedNotConfigured: number }> {
  const tokens = subscribersForTicker(params.ticker);
  if (tokens.length === 0) return { notified: 0, skippedNotConfigured: 0 };

  if (!isConfigured()) {
    // Placeholder path: log who *would* be notified so the matching/targeting
    // logic is verifiable today, without a paid Apple Developer account yet.
    console.log(
      `[push:placeholder] would notify ${tokens.length} device(s) about ${params.ticker}: "${params.title}"`
    );
    return { notified: 0, skippedNotConfigured: tokens.length };
  }

  let notified = 0;
  for (const deviceToken of tokens) {
    const result = await sendPush(deviceToken, { title: params.ticker, body: params.title, url: params.url });
    if (result.sent) {
      notified++;
    } else {
      console.warn(`[push] failed for ${deviceToken}: ${result.reason}`);
    }
  }
  return { notified, skippedNotConfigured: 0 };
}
