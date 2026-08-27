// Isele — the one shared setting: the laptop voice-server (Cloudflare tunnel) URL.
// The browser reads it (get_url); the START launcher pushes it (set_url) each run.
import Redis from 'ioredis';

// Accept whichever Redis URL is present — a manual REDIS_URL, or the one Vercel's
// Upstash/KV storage integration injects (KV_URL / UPSTASH_REDIS_URL).
const REDIS_URL = process.env.REDIS_URL || process.env.KV_URL || process.env.UPSTASH_REDIS_URL || '';
const redis = new Redis(REDIS_URL);
const URL_KEY = 'isele_wokada_url';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { action, url, secret } = req.body || {};

  try {
    if (action === 'get_url') {
      const u = await redis.get(URL_KEY);
      return res.status(200).json({ url: u || null });
    }

    if (action === 'set_url') {
      const CONTROL = process.env.ISELE_CONTROL_SECRET || '';
      if (!CONTROL || secret !== CONTROL) return res.status(403).json({ error: 'Unauthorized' });
      if (!url) return res.status(400).json({ error: 'Missing url' });
      await redis.set(URL_KEY, url);
      return res.status(200).json({ ok: true });
    }

    return res.status(400).json({ error: 'Unknown action' });
  } catch (err) {
    console.error('[config]', err);
    return res.status(500).json({ error: 'Server error' });
  }
}
