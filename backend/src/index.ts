import "dotenv/config";
import Fastify from "fastify";
import cron from "node-cron";
import "./db/client";
import { registerCompanyRoutes } from "./routes/companies";
import { registerAnnouncementRoutes } from "./routes/announcements";
import { registerCalendarRoutes } from "./routes/calendar";
import { registerSubscriptionRoutes } from "./routes/subscriptions";
import { pollEspiFeed } from "./sources/espiPoller";
import { scrapeEarningsCalendar } from "./sources/calendarScraper";
import { isConfigured as isApnsConfigured } from "./push/apns";

const app = Fastify({ logger: true });

app.get("/v1/health", async () => ({ status: "ok", apnsConfigured: isApnsConfigured() }));

registerCompanyRoutes(app);
registerAnnouncementRoutes(app);
registerCalendarRoutes(app);
registerSubscriptionRoutes(app);

async function runEspiPoll(): Promise<void> {
  try {
    const result = await pollEspiFeed();
    app.log.info({ result }, "espi poll completed");
  } catch (error) {
    app.log.error({ error }, "espi poll failed");
  }
}

async function runCalendarScrape(): Promise<void> {
  try {
    const result = await scrapeEarningsCalendar();
    app.log.info({ result }, "calendar scrape completed");
  } catch (error) {
    app.log.error({ error }, "calendar scrape failed");
  }
}

const PORT = Number(process.env.PORT) || 3000;

app
  .listen({ port: PORT, host: "0.0.0.0" })
  .then(() => {
    void runEspiPoll();
    void runCalendarScrape();
    cron.schedule("*/3 * * * *", runEspiPoll);
    cron.schedule("0 */12 * * *", runCalendarScrape);
  })
  .catch((error) => {
    app.log.error(error);
    process.exit(1);
  });
