# Isele — one-time setup. Points the laptop at reliable DNS (Google 8.8.8.8) so
# the secure tunnel can always connect. Some home/mobile networks hand out a DNS
# that can't do the lookup the tunnel needs; this fixes it once, for good.
# Run via "First-Time Setup.bat" (which elevates to admin for the DNS change).
$ErrorActionPreference = 'Continue'
Write-Host ''
Write-Host '   ISELE — First-Time Setup' -ForegroundColor Cyan
Write-Host '   Setting your laptop to use reliable internet lookups...' -ForegroundColor Gray
Write-Host ''

$done = $false
$adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
foreach ($a in $adapters) {
  try {
    Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses ('8.8.8.8','8.8.4.4') -ErrorAction Stop
    Write-Host ('   [ok] ' + $a.Name) -ForegroundColor Green
    $done = $true
  } catch {
    Write-Host ('   [!] could not set ' + $a.Name + ' : ' + $_.Exception.Message) -ForegroundColor Yellow
  }
}
try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch {}

Write-Host ''
if ($done) {
  Write-Host '   All set! You only need to run this setup ONCE.' -ForegroundColor Green
  Write-Host '   From now on, just double-click  START Isele  to use Isele.' -ForegroundColor Gray
} else {
  Write-Host '   No active network was found.' -ForegroundColor Yellow
  Write-Host '   Connect to Wi-Fi, then run First-Time Setup again.' -ForegroundColor Yellow
}
Write-Host ''
