import * as cheerio from "cheerio";
import { db } from "../db/client";

const SOURCE = "bankier_company_calendar";
const RESULTS_BADGE = "Wyniki spółek";

const insertEvent = db.prepare(`
  INSERT OR IGNORE INTO calendar_events
    (company_id, external_id, event_type, report_period, event_date, source_text)
  VALUES (@companyId, @externalId, 'periodic_report', NULL, @eventDate, @sourceText)
`);

const countForCompany = db.prepare(`SELECT COUNT(*) as c FROM calendar_events WHERE company_id = ?`);
const hasAttempted = db.prepare(`SELECT 1 FROM calendar_backfill_attempts WHERE company_id = ?`);
const recordAttempt = db.prepare(`INSERT OR IGNORE INTO calendar_backfill_attempts (company_id) VALUES (?)`);

/**
 * Replaces the original plan (stockwatch.pl/terminarz, a single global
 * paginated scrape covering every company) — that source turned out to be
 * too slow/unreliable in practice (see Faza 2 ryzyka w planie: requests
 * routinely exceeded a 30s timeout). bankier.pl's per-company calendar page
 * — the same domain already used for ESPI/EBI backfill — carries the same
 * "Wyniki spółek" (results) events with a ready-made unix timestamp per
 * date group, so this mirrors companyBackfill.ts: fetch once per ticker,
 * the first time it has zero calendar events on file.
 */
export async function backfillCalendarIfEmpty(ticker: string, companyId: number): Promise<number> {
  const existing = (countForCompany.get(companyId) as { c: number }).c;
  if (existing > 0) return 0;
  if (hasAttempted.get(companyId)) return 0;

  const url = `https://www.bankier.pl/gielda/notowania/akcje/${encodeURIComponent(ticker)}/kalendarium`;
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

  // Only recorded once we've actually got a page back, so a network hiccup
  // doesn't permanently block retrying — but a company with a valid, empty
  // kalendarium page won't be re-scraped on every future request.
  recordAttempt.run(companyId);

  let inserted = 0;
  try {
    const $ = cheerio.load(html);

    $(".m-quotes-calendar-list__item[data-timestamp]").each((_, dayGroup) => {
      const timestamp = Number($(dayGroup).attr("data-timestamp"));
      if (!Number.isFinite(timestamp)) return;
      const eventDate = new Date(timestamp * 1000).toISOString();

      $(dayGroup)
        .find(".m-quotes-calendar-list__event")
        .each((eventIdx, eventEl) => {
          const badge = $(eventEl).find(".a-quotes-badge .value").text().trim();
          if (badge !== RESULTS_BADGE) return;

          const sourceText = $(eventEl).find(".m-quotes-calendar-list__info").text().trim();
          if (!sourceText) return;

          const externalId = `${SOURCE}:${ticker}:${timestamp}:${eventIdx}`;
          const result = insertEvent.run({ companyId, externalId, eventDate, sourceText });
          if (result.changes > 0) inserted++;
        });
    });
  } catch {
    return inserted;
  }

  return inserted;
}
