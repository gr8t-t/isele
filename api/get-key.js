// Isele — returns the client's own Decart API key, gated by the single app password.
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { password } = req.body || {};
  const APP_PW = process.env.ISELE_PASSWORD || '';
  if (!APP_PW) return res.status(500).json({ error: 'App password not configured' });
  if (!password || password !== APP_PW) return res.status(403).json({ error: 'Wrong password' });

  const apiKey = process.env.DECART_API_KEY;
  if (!apiKey) return res.status(500).json({ error: 'Decart API key not configured' });

  return res.status(200).json({ key: apiKey });
}
