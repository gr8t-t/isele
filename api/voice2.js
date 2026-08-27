// Isele — single-user Voice 2.0 coordination. There's only one client, so they
// always own the slot; every action just succeeds. No queue, no Redis needed.
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { action } = req.body || {};
  switch (action) {
    case 'v2_status':     return res.status(200).json({ state: 'available', queueLen: 0 });
    case 'v2_acquire':    return res.status(200).json({ ok: true, state: 'active' });
    case 'v2_heartbeat':  return res.status(200).json({ ok: true });
    case 'v2_release':    return res.status(200).json({ ok: true });
    case 'v2_join_queue': return res.status(200).json({ state: 'available', queueLen: 0 });
    case 'v2_leave_queue':return res.status(200).json({ ok: true });
    case 'v1_can_start':  return res.status(200).json({ allowed: true });
    case 'v1_heartbeat':  return res.status(200).json({ ok: true });
    case 'v1_stop':       return res.status(200).json({ ok: true });
    default:              return res.status(400).json({ error: 'Unknown action' });
  }
}
