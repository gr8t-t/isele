# Isele

Standalone real-time video + voice (Voice 2.0 / Gleen Cook) app — a single-user,
no-billing fork of VNV Pro. The client uses their **own Decart API key**; there are
no coins, no payments, no multi-user login (just one app password).

## Architecture

- **Frontend** (this repo) → deployed to the client's **Vercel**.
- **Video** runs browser → Decart cloud directly (their Decart key).
- **Voice 2.0** runs on the **client's laptop** (w-okada + a small proxy + Cloudflare
  tunnel). The laptop's `START` launcher pushes the current tunnel URL to `/api/config`,
  which the app reads to reach the voice server.

## Vercel environment variables

| Variable | What it is |
|---|---|
| `DECART_API_KEY` | The client's own Decart API key (billed to them). |
| `ISELE_PASSWORD` | The single app password the client types to log in. |
| `REDIS_URL` | An Upstash Redis URL — stores only the current voice-server tunnel URL. |
| `ISELE_CONTROL_SECRET` | Shared secret the laptop launcher uses to push the tunnel URL (`/api/config` `set_url`). |

## Endpoints (`/api`)

- `get-key` — returns the Decart key if the posted password matches `ISELE_PASSWORD`.
- `config` — `get_url` (browser reads tunnel URL) / `set_url` (launcher pushes it, needs `ISELE_CONTROL_SECRET`).
- `voice2` — single-user Voice 2.0 stubs (the one client always owns the slot).

## The one voice

Gleen Cook — w-okada slot **9** (`gleencook.pth` / `gleencook.index`). The laptop
bundle ships that exact model.
