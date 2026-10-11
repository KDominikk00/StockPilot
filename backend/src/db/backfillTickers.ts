import { db } from "./client";

// Shared by routes/announcements.ts and routes/calendar.ts. Caps how many
// per-ticker backfill fetches run at once instead of firing one request per
// watched ticker simultaneously — bankier.pl is a third-party page, not an
// official API, and the predecessor scraper (deleted) was deliberately
// paced to avoid being tarpitted by its bot protection.
const CONCURRENCY = 3;

export async function backfillTickers(
  tickerList: string[],
  backfillFn: (ticker: string, companyId: number) => Promise<number>
): Promise<void> {
  const rows = db
    .prepare(`SELECT id, ticker FROM companies WHERE ticker IN (${tickerList.map(() => "?").join(",")})`)
    .all(...tickerList) as { id: number; ticker: string }[];

  let nextIndex = 0;
  async function worker(): Promise<void> {
    while (nextIndex < rows.length) {
      const row = rows[nextIndex++];
      await backfillFn(row.ticker, row.id);
    }
  }

  const workerCount = Math.min(CONCURRENCY, rows.length);
  await Promise.all(Array.from({ length: workerCount }, worker));
}
