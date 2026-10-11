import type { FastifyInstance } from "fastify";
import { db } from "../db/client";

interface SubscriptionBody {
  deviceToken?: string;
  tickers?: string[];
}

export function registerSubscriptionRoutes(app: FastifyInstance): void {
  app.post("/v1/subscriptions", async (request, reply) => {
    const { deviceToken, tickers } = request.body as SubscriptionBody;

    if (!deviceToken || !Array.isArray(tickers)) {
      return reply.code(400).send({ error: "deviceToken_and_tickers_required" });
    }

    const normalizedTickers = [...new Set(tickers.map((t) => t.trim().toUpperCase()).filter(Boolean))];

    const existing = db
      .prepare("SELECT id FROM device_subscriptions WHERE device_token = ?")
      .get(deviceToken) as { id: number } | undefined;

    const subscriptionId =
      existing?.id ??
      (db.prepare("INSERT INTO device_subscriptions (device_token) VALUES (?)").run(deviceToken)
        .lastInsertRowid as number);

    if (existing) {
      db.prepare(
        "UPDATE device_subscriptions SET last_seen_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?"
      ).run(subscriptionId);
    }

    db.prepare("DELETE FROM device_subscription_tickers WHERE device_subscription_id = ?").run(subscriptionId);

    const insertTicker = db.prepare(
      "INSERT INTO device_subscription_tickers (device_subscription_id, ticker) VALUES (?, ?)"
    );
    for (const ticker of normalizedTickers) {
      insertTicker.run(subscriptionId, ticker);
    }

    return { subscriptionId, tickers: normalizedTickers };
  });

  app.delete("/v1/subscriptions/:deviceToken", async (request) => {
    const { deviceToken } = request.params as { deviceToken: string };
    const existing = db
      .prepare("SELECT id FROM device_subscriptions WHERE device_token = ?")
      .get(deviceToken) as { id: number } | undefined;

    if (existing) {
      db.prepare("DELETE FROM device_subscription_tickers WHERE device_subscription_id = ?").run(existing.id);
      db.prepare("DELETE FROM device_subscriptions WHERE id = ?").run(existing.id);
    }

    return { deleted: Boolean(existing) };
  });
}
