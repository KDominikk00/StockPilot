import * as cheerio from "cheerio";
import { db } from "../db/client";
import { matchCompanyByName } from "../matching/companyMatcher";

const BASE_URL = "https://www.stockwatch.pl/async/CompaniesReportsView.aspx";
const SOURCE = "stockwatch_terminarz";
const MAX_PAGES = 30;

const insertEvent = db.prepare(`
  INSERT OR IGNORE INTO calendar_events
    (company_id, external_id, event_type, report_period, event_date, source_text)
  VALUES (@companyId, @externalId, @eventType, @reportPeriod, @eventDate, @sourceText)
`);

const insertUnmatched = db.prepare(`
  INSERT INTO unmatched_log (source, raw_name, external_id)
  VALUES (@source, @rawName, @externalId)
`);

interface ScrapedRow {
  shortName: string;
  slug: string;
  date: string;
  reportTypeRaw: string;
}

function parsePage(html: string): ScrapedRow[] {
  const $ = cheerio.load(html);
  const rows: ScrapedRow[] = [];

  $("table#StockRCal tbody tr").each((_, el) => {
    const row = $(el);
    const anchor = row.find("td").eq(0).find("a");
    const shortName = anchor.text().trim();
    const href = anchor.attr("href") ?? "";
    const slugMatch = href.match(/\/gpw\/([^,]+),/);
    const slug = slugMatch ? slugMatch[1] : shortName.toLowerCase();
    const date = row.find("td.c").text().trim();
    const reportTypeRaw = row.find("td.r").text().replace(/\s+/g, " ").trim();

    if (shortName && date) {
      rows.push({ shortName, slug, date, reportTypeRaw });
    }
  });

  return rows;
}

async function fetchPage(page: number): Promise<string> {
  const url = `${BASE_URL}?p=all&t=all&pg=${page}&IndexId=GPW`;
  const response = await fetch(url, {
    headers: { "User-Agent": "Mozilla/5.0 (compatible; GPWCommandCenterBot/0.1)" },
  });
  if (!response.ok) throw new Error(`stockwatch terminarz HTTP ${response.status}`);
  return response.text();
}

export interface CalendarScrapeResult {
  pagesFetched: number;
  rowsSeen: number;
  newEvents: number;
  matched: number;
  unmatched: number;
}

export async function scrapeEarningsCalendar(): Promise<CalendarScrapeResult> {
  let page = 0;
  let rowsSeen = 0;
  let newEvents = 0;
  let matched = 0;
  let unmatched = 0;

  while (page < MAX_PAGES) {
    const html = await fetchPage(page);
    const rows = parsePage(html);
    if (rows.length === 0) break;

    for (const row of rows) {
      rowsSeen++;
      const match = matchCompanyByName(row.shortName);
      const externalId = `${SOURCE}:${row.slug}:${row.date}:${row.reportTypeRaw}`;

      const result = insertEvent.run({
        companyId: match.companyId,
        externalId,
        eventType: "periodic_report",
        reportPeriod: null,
        eventDate: row.date,
        sourceText: row.reportTypeRaw,
      });

      if (result.changes > 0) {
        newEvents++;
        if (match.confidence === "unmatched") {
          unmatched++;
          insertUnmatched.run({ source: SOURCE, rawName: row.shortName, externalId });
        } else {
          matched++;
        }
      }
    }

    page++;
  }

  return { pagesFetched: page, rowsSeen, newEvents, matched, unmatched };
}
