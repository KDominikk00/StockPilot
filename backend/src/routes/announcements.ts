import type { FastifyInstance } from "fastify";
import { db } from "../db/client";
import { backfillAnnouncementsIfEmpty } from "../sources/companyBackfill";

interface AnnouncementsQuery {
  tickers?: string;
  limit?: string;
  cursor?: string;
}

async function backfillTickers(tickerList: string[]): Promise<void> {
  const rows = db
    .prepare(`SELECT id, ticker FROM companies WHERE ticker IN (${tickerList.map(() => "?").join(",")})`)
    .all(...tickerList) as { id: number; ticker: string }[];

  await Promise.all(rows.map((row) => backfillAnnouncementsIfEmpty(row.ticker, row.id)));
}

export function registerAnnouncementRoutes(app: FastifyInstance): void {
  app.get("/v1/announcements", async (request) => {
    const { tickers, limit, cursor } = request.query as AnnouncementsQuery;
    const pageSize = Math.min(Number(limit) || 50, 200);

    const tickerList = tickers
      ?.split(",")
      .map((t) => t.trim().toUpperCase())
      .filter(Boolean);

    if (!tickerList || tickerList.length === 0) {
      return { items: [], nextCursor: null };
    }

    await backfillTickers(tickerList);

    const placeholders = tickerList.map(() => "?").join(",");
    const params: (string | number)[] = [...tickerList];

    let cursorClause = "";
    if (cursor) {
      cursorClause = "AND a.published_at < ?";
      params.push(cursor);
    }

    const rows = db
      .prepare(
        `SELECT a.external_id, a.title, a.url, a.published_at, a.match_confidence, a.source, c.ticker
         FROM announcements a
         JOIN companies c ON c.id = a.company_id
         WHERE c.ticker IN (${placeholders}) ${cursorClause}
         ORDER BY a.published_at DESC
         LIMIT ?`
      )
      .all(...params, pageSize + 1);

    const hasMore = rows.length > pageSize;
    const items = rows.slice(0, pageSize);
    const nextCursor = hasMore ? (items[items.length - 1] as any).published_at : null;

    return { items, nextCursor };
  });

  app.get("/v1/companies/:ticker/announcements", async (request) => {
    const { ticker } = request.params as { ticker: string };
    await backfillTickers([ticker.toUpperCase()]);
    return db
      .prepare(
        `SELECT a.external_id, a.title, a.url, a.published_at, a.match_confidence, a.source
         FROM announcements a
         JOIN companies c ON c.id = a.company_id
         WHERE c.ticker = ?
         ORDER BY a.published_at DESC
         LIMIT 100`
      )
      .all(ticker.toUpperCase());
  });
}
