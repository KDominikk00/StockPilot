// POST /api/waitlist  { email, lang, consent, hp }
// Stores signups in Upstash Redis (REST) under the hash "waitlist": email -> {ts, lang}.
// Env: KV_REST_API_URL + KV_REST_API_TOKEN (Vercel Marketplace Upstash/KV) or UPSTASH_REDIS_REST_URL/_TOKEN.
const crypto = require('node:crypto');

const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,255}\.[^\s@]{2,}$/;
const RATE_LIMIT = 5;          // requests
const RATE_WINDOW_S = 3600;    // per hour, per IP

const redisCfg = () => ({
  url: process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL,
  token: process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN,
});

async function pipeline(cfg, commands) {
  const r = await fetch(`${cfg.url.replace(/\/$/, '')}/pipeline`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${cfg.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(commands),
  });
  if (!r.ok) throw new Error(`redis ${r.status}`);
  return r.json();
}

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') { res.setHeader('Allow', 'POST'); return res.status(405).json({ ok: false, error: 'method' }); }

  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch { body = null; } }
  if (!body || typeof body !== 'object') return res.status(400).json({ ok: false, error: 'invalid' });

  // Honeypot: pretend success so bots learn nothing.
  if (body.hp) return res.status(200).json({ ok: true });

  const email = String(body.email || '').trim().toLowerCase();
  if (email.length > 254 || !EMAIL_RE.test(email)) return res.status(400).json({ ok: false, error: 'email' });
  if (body.consent !== true) return res.status(400).json({ ok: false, error: 'consent' });
  const lang = body.lang === 'pl' ? 'pl' : 'en';

  const cfg = redisCfg();
  if (!cfg.url || !cfg.token) return res.status(503).json({ ok: false, error: 'not_configured' });

  try {
    const ip = String(req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '').split(',')[0].trim();
    const ipKey = 'wl:rl:' + crypto.createHash('sha256').update(ip).digest('hex').slice(0, 32);
    const [incr] = await pipeline(cfg, [['INCR', ipKey], ['EXPIRE', ipKey, RATE_WINDOW_S, 'NX']]);
    if (Number(incr.result) > RATE_LIMIT) return res.status(429).json({ ok: false, error: 'rate' });

    // HSETNX keeps the original signup time and makes duplicates a no-op.
    await pipeline(cfg, [['HSETNX', 'waitlist', email, JSON.stringify({ ts: new Date().toISOString(), lang })]]);
    return res.status(200).json({ ok: true });
  } catch (e) {
    return res.status(502).json({ ok: false, error: 'storage' });
  }
};
