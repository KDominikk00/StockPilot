import fs from "node:fs";
import http2 from "node:http2";
import jwt from "jsonwebtoken";

export interface PushPayload {
  title: string;
  body: string;
  url?: string;
}

export type SendPushResult = { sent: true } | { sent: false; reason: string };

interface ApnsConfig {
  keyPath: string;
  keyId: string;
  teamId: string;
  bundleId: string;
  host: string;
}

/**
 * APNs push is a placeholder until the project has a paid Apple Developer
 * account (push requires the Push Notifications capability + an APNs auth
 * key, neither available on a free account). The business logic that
 * decides WHEN to push is fully wired up (see push/notifier.ts) — only this
 * module's actual network call is gated, so flipping APNS_* env vars on
 * later requires no code changes.
 */
function loadConfig(): ApnsConfig | null {
  const keyPath = process.env.APNS_KEY_PATH;
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const bundleId = process.env.APNS_BUNDLE_ID;

  if (!keyPath || !keyId || !teamId || !bundleId) return null;
  if (!fs.existsSync(keyPath)) return null;

  const host =
    process.env.APNS_ENV === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";

  return { keyPath, keyId, teamId, bundleId, host };
}

export function isConfigured(): boolean {
  return loadConfig() !== null;
}

let cachedToken: { value: string; issuedAt: number } | null = null;
const TOKEN_TTL_MS = 50 * 60 * 1000;

function getAuthToken(config: ApnsConfig): string {
  if (cachedToken && Date.now() - cachedToken.issuedAt < TOKEN_TTL_MS) {
    return cachedToken.value;
  }
  const privateKey = fs.readFileSync(config.keyPath, "utf-8");
  const token = jwt.sign({ iss: config.teamId, iat: Math.floor(Date.now() / 1000) }, privateKey, {
    algorithm: "ES256",
    header: { alg: "ES256", kid: config.keyId },
  });
  cachedToken = { value: token, issuedAt: Date.now() };
  return token;
}

export async function sendPush(deviceToken: string, payload: PushPayload): Promise<SendPushResult> {
  const config = loadConfig();
  if (!config) {
    return { sent: false, reason: "apns_not_configured" };
  }

  const token = getAuthToken(config);
  const body = JSON.stringify({
    aps: { alert: { title: payload.title, body: payload.body }, sound: "default" },
    url: payload.url,
  });

  return new Promise((resolve) => {
    const client = http2.connect(config.host);
    client.on("error", (error) => resolve({ sent: false, reason: error.message }));

    const req = client.request({
      ":method": "POST",
      ":path": `/3/device/${deviceToken}`,
      authorization: `bearer ${token}`,
      "apns-topic": config.bundleId,
      "apns-push-type": "alert",
      "content-type": "application/json",
    });

    let responseStatus = 0;
    req.on("response", (headers) => {
      responseStatus = Number(headers[":status"] ?? 0);
    });

    let responseBody = "";
    req.on("data", (chunk) => {
      responseBody += chunk;
    });

    req.on("end", () => {
      client.close();
      if (responseStatus === 200) {
        resolve({ sent: true });
      } else {
        resolve({ sent: false, reason: `apns_http_${responseStatus}:${responseBody}` });
      }
    });

    req.on("error", (error) => {
      client.close();
      resolve({ sent: false, reason: error.message });
    });

    req.end(body);
  });
}
