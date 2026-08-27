# Isele — building the client bundle (for gr8t-t)

Two things to ship: **(A)** deploy the web app to the client's Vercel, and **(B)**
build the `Isele.zip` the client double-clicks. Do A first (you need the app URL).

## A) Deploy the web app (client's Vercel)

1. Push this repo to a GitHub repo, import it into the **client's Vercel** account.
2. Set these Environment Variables (Production):
   - `DECART_API_KEY` — the client's own Decart key
   - `ISELE_PASSWORD` — the password the client will type to log in
   - `REDIS_URL` — a free Upstash Redis URL (only stores the tunnel URL)
   - `ISELE_CONTROL_SECRET` — any long random string (the launcher uses it)
3. Deploy. Note the app URL, e.g. `https://isele-client.vercel.app`.

## B) Build the laptop bundle

On this machine (has w-okada, cloudflared, the Gleen model):

1. **Fill `config.txt`** in this folder:
   ```
   APP_URL=https://isele-client.vercel.app
   CONTROL_SECRET=<the same ISELE_CONTROL_SECRET you set in Vercel>
   ```
2. **Build the proxy exe** (once):
   ```
   powershell -ExecutionPolicy Bypass -File build-proxy.ps1
   ```
   → produces `isele-proxy.exe`.
3. **Assemble + zip**:
   ```
   powershell -ExecutionPolicy Bypass -File build-bundle.ps1
   ```
   → produces `Desktop\Isele.zip` (a few GB) containing a self-contained `Isele\` folder:
   `START Isele.bat`, `isele-launch.ps1`, `config.txt`, `isele-proxy.exe`,
   `cloudflared.exe`, and `wokada\` (w-okada with Gleen in slot 9 only).

## C) Send to the client

Upload `Isele.zip` (Google Drive / WeTransfer) and send the link + the picture guide.
The client: download → unzip → double-click **START Isele.bat**. First run, Windows
may show "Windows protected your PC" → **More info → Run anyway**.

## Notes

- The bundle keeps only w-okada **slot 9** (Gleen). The app selects that slot at stream
  start, so w-okada loads the model on demand. If w-okada logs a missing-slot warning on
  startup, it's harmless.
- Quick Cloudflare tunnels get a new URL each run; the launcher pushes it to
  `/api/config` automatically, so the client never copies a URL.
- To change the app password or Decart key later: update the Vercel env var and redeploy —
  no new bundle needed. To change the app URL: edit `config.txt` and re-zip.
