import Fastify from "fastify";
import cron from "node-cron";
import "./db/client";
import { registerCompanyRoutes } from "./routes/companies";
import { registerAnnouncementRoutes } from "./routes/announcements";
import { pollEspiFeed } from "./sources/espiPoller";

const app = Fastify({ logger: true });

app.get("/v1/health", async () => ({ status: "ok" }));

registerCompanyRoutes(app);
registerAnnouncementRoutes(app);

async function runEspiPoll(): Promise<void> {
  try {
    const result = await pollEspiFeed();
    app.log.info({ result }, "espi poll completed");
  } catch (error) {
    app.log.error({ error }, "espi poll failed");
  }
}

const PORT = Number(process.env.PORT) || 3000;

app
  .listen({ port: PORT, host: "0.0.0.0" })
  .then(() => {
    void runEspiPoll();
    cron.schedule("*/3 * * * *", runEspiPoll);
  })
  .catch((error) => {
    app.log.error(error);
    process.exit(1);
  });
