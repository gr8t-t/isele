# ─────────────────────────────────────────────────────────────────────────────
#  Isele launcher — starts everything the client's laptop needs, in one go:
#    1. w-okada  (the Voice 2.0 engine, Gleen Cook in slot 9)   :18000
#    2. Isele proxy (CORS + /v2 bridge to w-okada)              :8765
#    3. Cloudflare quick tunnel  ->  the proxy
#    4. Pushes the tunnel URL to the Isele web app (/api/config)
#    5. Opens the Isele app in the browser
#  It then keeps running and re-pushes the URL if the tunnel ever changes.
#  Closing this window stops everything.
# ─────────────────────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot

# Keep the laptop awake while Isele is running (ES_CONTINUOUS | ES_SYSTEM_REQUIRED)
Add-Type -Namespace IseleAwake -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);' -ErrorAction SilentlyContinue
try { [void][IseleAwake.Power]::SetThreadExecutionState(2147483649) } catch {}

# ── Read config.txt (APP_URL + CONTROL_SECRET) ───────────────────────────────
$cfgFile = Join-Path $root 'config.txt'
$AppUrl = ''; $Secret = ''
if (Test-Path $cfgFile) {
  foreach ($line in Get-Content $cfgFile) {
    if ($line -match '^\s*APP_URL\s*=\s*(.+?)\s*$')        { $AppUrl = $Matches[1].Trim() }
    elseif ($line -match '^\s*CONTROL_SECRET\s*=\s*(.+?)\s*$') { $Secret = $Matches[1].Trim() }
  }
}
$AppUrl = $AppUrl.TrimEnd('/')

$wokDir   = Join-Path $root 'wokada'
$wokExe   = Join-Path $wokDir 'main.exe'
$proxyExe = Join-Path $root 'isele-proxy.exe'
$pyExe    = Join-Path $root 'python\python.exe'
$proxyPy  = Join-Path $root 'proxy.py'
$cfExe    = Join-Path $root 'cloudflared.exe'
$logDir   = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$wokLog = Join-Path $logDir 'wokada.log'
$proxyLog = Join-Path $logDir 'proxy.log'
$cfLog  = Join-Path $logDir 'cloudflared.log'

function Say($m, $c='Gray') { Write-Host $m -ForegroundColor $c }

function Test-Http($url) {
  try { $r = Invoke-WebRequest -Uri $url -TimeoutSec 4 -UseBasicParsing; return ($r.StatusCode -eq 200) }
  catch { return $false }
}

Clear-Host
Say ''
Say '   ISELE' 'Cyan'
Say '   Starting your video + voice studio...' 'DarkCyan'
Say ''

# ── 1) w-okada (Voice 2.0) ───────────────────────────────────────────────────
if (-not (Get-Process main -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $wokExe })) {
  if (Test-Path $wokExe) {
    Say '   * Starting the voice engine...' 'Gray'
    Start-Process -WindowStyle Hidden -FilePath cmd -ArgumentList '/c', "cd /d `"$wokDir`" && `"$wokExe`" cui --https false --no_cui True > `"$wokLog`" 2>&1"
  } else {
    Say "   ! Voice engine not found at $wokExe" 'Red'
  }
}

# ── 2) Isele proxy ───────────────────────────────────────────────────────────
if (-not (Get-Process isele-proxy -ErrorAction SilentlyContinue) -and -not (Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $pyExe })) {
  if (Test-Path $proxyExe) {
    Say '   * Starting the Isele proxy...' 'Gray'
    Start-Process -WindowStyle Hidden -FilePath cmd -ArgumentList '/c', "`"$proxyExe`" 8765 > `"$proxyLog`" 2>&1"
  } elseif ((Test-Path $pyExe) -and (Test-Path $proxyPy)) {
    Start-Process -WindowStyle Hidden -FilePath cmd -ArgumentList '/c', "`"$pyExe`" `"$proxyPy`" 8765 > `"$proxyLog`" 2>&1"
  } else {
    Say '   ! Isele proxy not found (need isele-proxy.exe or python\python.exe + proxy.py)' 'Red'
  }
}

# ── Wait for the proxy + w-okada to answer ───────────────────────────────────
Say '   * Warming up the engine (this can take up to a minute)...' 'Gray'
$ok = $false
for ($i = 0; $i -lt 60; $i++) {
  if ((Test-Http 'http://127.0.0.1:8765/health')) { $ok = $true; break }
  Start-Sleep -Seconds 1
}
if (-not $ok) { Say '   ! Proxy did not start. See logs\proxy.log' 'Red' }
# w-okada takes longer to load the model; poll its health via the proxy
for ($i = 0; $i -lt 90; $i++) {
  if ((Test-Http 'http://127.0.0.1:8765/v2/health')) { break }
  Start-Sleep -Seconds 1
}

# ── 3) Cloudflare tunnel ─────────────────────────────────────────────────────
if (-not (Get-Process cloudflared -ErrorAction SilentlyContinue)) {
  if (Test-Path $cfExe) {
    Say '   * Opening a secure tunnel...' 'Gray'
    if (Test-Path $cfLog) { Remove-Item $cfLog -Force -ErrorAction SilentlyContinue }
    Start-Process -WindowStyle Hidden -FilePath cmd -ArgumentList '/c', "`"$cfExe`" tunnel --url http://127.0.0.1:8765 > `"$cfLog`" 2>&1"
  } else {
    Say "   ! cloudflared.exe not found at $cfExe" 'Red'
  }
}

function Get-TunnelUrl {
  if (-not (Test-Path $cfLog)) { return $null }
  try {
    $txt = Get-Content -Raw -Path $cfLog -ErrorAction SilentlyContinue
    $m = [regex]::Match($txt, 'https://[a-z0-9-]+\.trycloudflare\.com')
    if ($m.Success) { return $m.Value }
  } catch {}
  return $null
}

function Push-Url($u) {
  if (-not $AppUrl) { Say '   ! APP_URL is empty in config.txt — cannot connect the app.' 'Red'; return $false }
  try {
    $body = @{ action = 'set_url'; url = $u; secret = $Secret } | ConvertTo-Json
    Invoke-RestMethod -Uri "$AppUrl/api/config" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 15 | Out-Null
    return $true
  } catch { Say "   ! Could not reach the app to send the tunnel URL: $($_.Exception.Message)" 'Red'; return $false }
}

# ── 4) Grab the tunnel URL and push it to the app ────────────────────────────
$tunnel = $null
for ($i = 0; $i -lt 40; $i++) { $tunnel = Get-TunnelUrl; if ($tunnel) { break }; Start-Sleep -Seconds 1 }
$pushed = $null
if ($tunnel) {
  if (Push-Url $tunnel) { $pushed = $tunnel; Say '   * Connected.' 'Green' }
} else {
  Say '   ! Tunnel did not come up. See logs\cloudflared.log' 'Red'
}

# ── 5) Open the app ──────────────────────────────────────────────────────────
if ($AppUrl) { Start-Process $AppUrl }

Say ''
Say '   ================================================' 'DarkCyan'
Say '   Isele is running.  Keep this window open.' 'Cyan'
Say '   Close it to stop everything.' 'DarkGray'
Say '   ================================================' 'DarkCyan'
Say ''

# ── Keep alive + self-heal: re-push if the tunnel URL changes ────────────────
while ($true) {
  Start-Sleep -Seconds 20
  $now = Get-TunnelUrl
  if ($now -and $now -ne $pushed) {
    if (Push-Url $now) { $pushed = $now; Say "   * Reconnected (tunnel changed)." 'Green' }
  }
}
