import type { FastifyInstance } from "fastify";
import { db } from "../db/client";

export function registerCompanyRoutes(app: FastifyInstance): void {
  app.get("/v1/companies", async (request) => {
    const { query } = request.query as { query?: string };

    if (query && query.trim().length > 0) {
      const like = `%${query.trim().toUpperCase()}%`;
      return db
        .prepare(
          `SELECT ticker, isin, name_full FROM companies
           WHERE is_active = 1 AND (UPPER(name_full) LIKE ? OR UPPER(ticker) LIKE ? OR UPPER(isin) LIKE ?)
           ORDER BY name_full LIMIT 100`
        )
        .all(like, like, like);
    }

    return db.prepare("SELECT ticker, isin, name_full FROM companies WHERE is_active = 1 ORDER BY name_full").all();
  });

  app.get("/v1/companies/:ticker", async (request, reply) => {
    const { ticker } = request.params as { ticker: string };
    const company = db
      .prepare("SELECT ticker, isin, name_full FROM companies WHERE ticker = ?")
      .get(ticker.toUpperCase());

    if (!company) {
      return reply.code(404).send({ error: "company_not_found" });
    }
    return company;
  });
}
