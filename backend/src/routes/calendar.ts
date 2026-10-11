import type { FastifyInstance } from "fastify";
import { db } from "../db/client";
import { backfillCalendarIfEmpty } from "../sources/companyCalendarBackfill";
import { backfillTickers } from "../db/backfillTickers";

interface CalendarQuery {
  tickers?: string;
  from?: string;
  to?: string;
}

export function registerCalendarRoutes(app: FastifyInstance): void {
  app.get("/v1/calendar", async (request) => {
    const { tickers, from, to } = request.query as CalendarQuery;

    const tickerList = tickers
      ?.split(",")
      .map((t) => t.trim().toUpperCase())
      .filter(Boolean);

    if (!tickerList || tickerList.length === 0) {
      return { items: [] };
    }

    await backfillTickers(tickerList, backfillCalendarIfEmpty);

    const placeholders = tickerList.map(() => "?").join(",");
    const params: string[] = [...tickerList];

    let dateClause = "";
    if (from) {
      dateClause += " AND e.event_date >= ?";
      params.push(from);
    }
    if (to) {
      dateClause += " AND e.event_date <= ?";
      params.push(to);
    }

    return {
      items: db
        .prepare(
          `SELECT e.external_id, e.event_type, e.event_date, e.source_text, c.ticker
           FROM calendar_events e
           JOIN companies c ON c.id = e.company_id
           WHERE c.ticker IN (${placeholders}) ${dateClause}
           ORDER BY e.event_date ASC`
        )
        .all(...params),
    };
  });

  app.get("/v1/companies/:ticker/calendar", async (request) => {
    const { ticker } = request.params as { ticker: string };
    await backfillTickers([ticker.toUpperCase()], backfillCalendarIfEmpty);
    return db
      .prepare(
        `SELECT e.external_id, e.event_type, e.event_date, e.source_text
         FROM calendar_events e
         JOIN companies c ON c.id = e.company_id
         WHERE c.ticker = ?
         ORDER BY e.event_date ASC`
      )
      .all(ticker.toUpperCase());
  });
}
