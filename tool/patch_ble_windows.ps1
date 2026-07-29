# Patches ble_peripheral_plus Windows plugin after flutter pub get.
$ErrorActionPreference = "Stop"

$pkgRoot = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"
$pkg = Get-ChildItem $pkgRoot -Directory -Filter "ble_peripheral_plus-*" |
  Sort-Object Name -Descending |
  Select-Object -First 1

if (-not $pkg) {
  Write-Host "ble_peripheral_plus not found - run flutter pub get first"
  exit 0
}

$windows = Join-Path $pkg.FullName "windows"
$cmake = Join-Path $windows "CMakeLists.txt"
$includeSrc = Join-Path $windows "include\ble_peripheral"
$includeDst = Join-Path $windows "include\ble_peripheral_plus"

$content = Get-Content $cmake -Raw
$content = $content -replace 'set\(PLUGIN_NAME "ble_peripheral_plugin"\)',
  'set(PLUGIN_NAME "ble_peripheral_plus_plugin")'
Set-Content $cmake $content -NoNewline

if ((Test-Path $includeSrc) -and -not (Test-Path $includeDst)) {
  cmd /c mklink /J "$includeDst" "$includeSrc"
  Write-Host "Created include junction"
}

Write-Host "Patched ble_peripheral_plus for Windows"
