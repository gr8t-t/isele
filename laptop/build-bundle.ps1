# Assembles the client ZIP: a self-contained "Isele" folder they unzip and run.
# Prereqs on THIS machine:
#   - laptop\isele-proxy.exe  (run build-proxy.ps1 first)
#   - w-okada installed        (default path below; override with -WokadaDir)
#   - cloudflared.exe          (default path below; override with -CloudflaredExe)
#   - config.txt filled in     (APP_URL + CONTROL_SECRET for the client)
#
# Output: <Desktop>\Isele-dist\Isele\  and  <Desktop>\Isele.zip
param(
  [string]$WokadaDir      = 'C:\Users\USER\Downloads\vcclient_win_cuda_2.0.78-beta\dist\main',
  [string]$CloudflaredExe = 'C:\Users\USER\cloudflared\cloudflared.exe',
  [int[]] $Slots          = @(6, 9)   # 9 = Gleen Cook, 6 = Sarah Miller
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$desktop = [Environment]::GetFolderPath('Desktop')
$stage = Join-Path $desktop 'Isele-dist\Isele'
$zip   = Join-Path $desktop 'Isele.zip'

function Need($path, $what) { if (-not (Test-Path $path)) { Write-Host "MISSING: $what -> $path" -ForegroundColor Red; exit 1 } }
Need (Join-Path $root 'isele-proxy.exe') 'proxy exe (run build-proxy.ps1)'
Need $CloudflaredExe 'cloudflared.exe'
Need (Join-Path $WokadaDir 'main.exe') 'w-okada main.exe'
Need (Join-Path $WokadaDir "model_dir\9\gleencook.pth") "Gleen model (slot 9)"
Need (Join-Path $WokadaDir "model_dir\6\SarahMiller500E.pth") "Sarah model (slot 6)"

if (Test-Path (Join-Path $desktop 'Isele-dist')) { Remove-Item (Join-Path $desktop 'Isele-dist') -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

# ── w-okada, minus the other voice slots / scratch dirs (keep only Gleen) ─────
Write-Host 'Copying voice engine (w-okada)...' -ForegroundColor Cyan
$wokStage = Join-Path $stage 'wokada'
# /E all subdirs, /XD exclude these dir trees (copy model_dir separately, drop scratch)
robocopy $WokadaDir $wokStage /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XF 'vcclient.log' `
  /XD (Join-Path $WokadaDir 'model_dir') (Join-Path $WokadaDir 'tmp_dir') (Join-Path $WokadaDir 'upload_dir') | Out-Null
# just the voices we ship (Gleen slot 9, Sarah slot 6), without the .bak files
foreach ($slot in $Slots) {
  $slotSrc = Join-Path $WokadaDir "model_dir\$slot"
  $slotDst = Join-Path $wokStage "model_dir\$slot"
  New-Item -ItemType Directory -Force -Path $slotDst | Out-Null
  Get-ChildItem $slotSrc -File | Where-Object { $_.Name -notlike '*.bak' } | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $slotDst $_.Name) -Force
  }
}
# fresh log
Remove-Item (Join-Path $wokStage 'vcclient.log') -Force -ErrorAction SilentlyContinue

# ── the rest of the bundle ───────────────────────────────────────────────────
Write-Host 'Copying tunnel, proxy, launcher...' -ForegroundColor Cyan
Copy-Item $CloudflaredExe (Join-Path $stage 'cloudflared.exe') -Force
Copy-Item (Join-Path $root 'isele-proxy.exe')  $stage -Force
Copy-Item (Join-Path $root 'isele-launch.ps1')     $stage -Force
Copy-Item (Join-Path $root 'START Isele.bat')      $stage -Force
Copy-Item (Join-Path $root 'STOP Isele.bat')       $stage -Force
Copy-Item (Join-Path $root 'First-Time Setup.bat') $stage -Force
Copy-Item (Join-Path $root 'isele-setup.ps1')      $stage -Force
Copy-Item (Join-Path $root 'config.txt')           $stage -Force
Copy-Item (Join-Path $root 'proxy.py')             $stage -Force   # fallback if the exe is blocked

Write-Host ''
$cfg = Get-Content (Join-Path $stage 'config.txt') -Raw
if ($cfg -match 'REPLACE-ME') { Write-Host '!! config.txt still has REPLACE-ME — edit it before sending to the client.' -ForegroundColor Yellow }

# ── zip it (contents at ROOT so "Extract All" gives ONE clean Isele folder,
#    not Isele\Isele — critical for a non-technical user) ──────────────────────
Write-Host 'Zipping...' -ForegroundColor Cyan
if (Test-Path $zip) { Remove-Item $zip -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
  (Join-Path $desktop 'Isele-dist\Isele'), $zip,
  [System.IO.Compression.CompressionLevel]::Optimal, $false)
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 0)
Write-Host "Done -> $zip  (${mb} MB)" -ForegroundColor Green
Write-Host "Folder: $stage" -ForegroundColor Green
