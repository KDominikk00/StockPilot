import Parser from "rss-parser";
import { db } from "../db/client";
import { extractCompanyNameFromEspiTitle, matchCompanyByName } from "../matching/companyMatcher";
import { notifyNewAnnouncement } from "../push/notifier";

const ESPI_FEED_URL = "https://www.bankier.pl/rss/espi.xml";
const SOURCE = "bankier_espi";

const parser = new Parser();

const insertAnnouncement = db.prepare(`
  INSERT OR IGNORE INTO announcements
    (company_id, external_id, source, title, raw_text, url, published_at, match_confidence, matched_name)
  VALUES (@companyId, @externalId, @source, @title, @rawText, @url, @publishedAt, @matchConfidence, @matchedName)
`);

const insertUnmatched = db.prepare(`
  INSERT INTO unmatched_log (source, raw_name, external_id)
  VALUES (@source, @rawName, @externalId)
`);

export interface PollResult {
  fetchedItems: number;
  newItems: number;
  matched: number;
  unmatched: number;
}

export async function pollEspiFeed(): Promise<PollResult> {
  const feed = await parser.parseURL(ESPI_FEED_URL);

  let newItems = 0;
  let matched = 0;
  let unmatched = 0;

  for (const item of feed.items) {
    const externalId = item.guid ?? item.link;
    const title = item.title ?? "";
    const url = item.link ?? "";
    const publishedAt = item.pubDate ? new Date(item.pubDate).toISOString() : new Date().toISOString();

    if (!externalId || !title || !url) continue;

    const companyName = extractCompanyNameFromEspiTitle(title);
    const match = matchCompanyByName(companyName);

    const result = insertAnnouncement.run({
      companyId: match.companyId,
      externalId,
      source: SOURCE,
      title,
      rawText: item.contentSnippet ?? null,
      url,
      publishedAt,
      matchConfidence: match.confidence,
      matchedName: companyName,
    });

    if (result.changes > 0) {
      newItems++;
      if (match.confidence === "unmatched" || !match.ticker) {
        unmatched++;
        insertUnmatched.run({ source: SOURCE, rawName: companyName, externalId });
      } else {
        matched++;
        await notifyNewAnnouncement({ ticker: match.ticker, title, url });
      }
    }
  }

  return { fetchedItems: feed.items.length, newItems, matched, unmatched };
}
