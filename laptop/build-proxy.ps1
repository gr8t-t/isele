# Builds isele-proxy.exe from proxy.py (portable, no torch).
# Run once on any Windows machine with Python 3.9+; produces laptop\isele-proxy.exe.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$build = Join-Path $root '_build'
$venv = Join-Path $build 'venv'

# Pick a Python to bootstrap the build venv (py launcher, then python on PATH)
$py = $null
foreach ($cand in @('py', 'python')) {
  try { & $cand --version *> $null; if ($LASTEXITCODE -eq 0) { $py = $cand; break } } catch {}
}
if (-not $py) { Write-Host 'No Python found on PATH to build with. Install Python 3.9+ and retry.' -ForegroundColor Red; exit 1 }

New-Item -ItemType Directory -Force -Path $build | Out-Null
if (-not (Test-Path (Join-Path $venv 'Scripts\python.exe'))) {
  Write-Host 'Creating build venv...' -ForegroundColor Cyan
  & $py -m venv $venv
}
$vpy = Join-Path $venv 'Scripts\python.exe'

Write-Host 'Installing build deps (numpy, soxr, requests, pyinstaller)...' -ForegroundColor Cyan
& $vpy -m pip install --upgrade pip *> $null
& $vpy -m pip install numpy soxr requests pyinstaller

Write-Host 'Freezing proxy.py -> isele-proxy.exe ...' -ForegroundColor Cyan
Push-Location $build
& $vpy -m PyInstaller --onefile --name isele-proxy `
    --hidden-import soxr `
    (Join-Path $root 'proxy.py')
Pop-Location

$out = Join-Path $build 'dist\isele-proxy.exe'
if (Test-Path $out) {
  Copy-Item $out (Join-Path $root 'isele-proxy.exe') -Force
  Write-Host "Done -> $(Join-Path $root 'isele-proxy.exe')" -ForegroundColor Green
} else {
  Write-Host 'Build failed — isele-proxy.exe not produced. Check the PyInstaller output above.' -ForegroundColor Red
  exit 1
}
