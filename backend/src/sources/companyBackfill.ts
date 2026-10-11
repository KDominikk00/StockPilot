import * as cheerio from "cheerio";
import { db } from "../db/client";

const SOURCE = "bankier_company_backfill";
const MAX_BACKFILL_ITEMS = 15;

const insertAnnouncement = db.prepare(`
  INSERT OR IGNORE INTO announcements
    (company_id, external_id, source, title, raw_text, url, published_at, match_confidence, matched_name)
  VALUES (@companyId, @externalId, @source, @title, NULL, @url, @publishedAt, 'exact', @matchedName)
`);

const countForCompany = db.prepare(`SELECT COUNT(*) as c FROM announcements WHERE company_id = ?`);

function parseDate(raw: string): string | null {
  const m = raw.trim().match(/^(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})$/);
  if (!m) return null;
  const [, dd, mm, yyyy, hh, min] = m;
  return `${yyyy}-${mm}-${dd}T${hh}:${min}:00.000Z`;
}

/**
 * The live ESPI poller (espiPoller.ts) only ever sees the ~20-30 newest
 * items across ALL companies, so a watched company with nothing very recent
 * shows up with an empty feed. This backfills a company's own komunikaty
 * history (bankier.pl's per-company page, which — unlike the RSS feed —
 * accepts our GPW ticker directly) once, the first time it's requested with
 * zero announcements on file, so the list isn't empty on day one.
 */
export async function backfillAnnouncementsIfEmpty(ticker: string, companyId: number): Promise<number> {
  const existing = (countForCompany.get(companyId) as { c: number }).c;
  if (existing > 0) return 0;

  const url = `https://www.bankier.pl/gielda/notowania/akcje/${encodeURIComponent(ticker)}/komunikaty`;
  let html: string;
  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
      },
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) return 0;
    html = await response.text();
  } catch {
    return 0;
  }

  const $ = cheerio.load(html);
  let inserted = 0;

  $(".m-quotes-announcements-list__item")
    .slice(0, MAX_BACKFILL_ITEMS)
    .each((_, el) => {
      const item = $(el);
      const dateText = item.find(".m-quotes-announcements-item__date").text();
      const anchor = item.find(".m-quotes-announcements-item__anchor");
      const title = anchor.text().trim();
      const href = anchor.attr("href");
      const publishedAt = parseDate(dateText);
      if (!title || !href || !publishedAt) return;

      const result = insertAnnouncement.run({
        companyId,
        externalId: href,
        source: SOURCE,
        title,
        url: href,
        publishedAt,
        matchedName: ticker,
      });
      if (result.changes > 0) inserted++;
    });

  return inserted;
}
