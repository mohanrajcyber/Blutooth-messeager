# BT Messenger — first-time setup (Windows)

Write-Host "BT Messenger setup" -ForegroundColor Green

# Check Flutter
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Host "Flutter not found. Install from: https://docs.flutter.dev/get-started/install/windows"
    Write-Host "Or run: winget install Google.Flutter"
    exit 1
}

Set-Location $PSScriptRoot\..

Write-Host "`nGenerating platform folders..." -ForegroundColor Cyan
flutter create . --project-name bluetooth_messenger --platforms=android,windows

Write-Host "`nInstalling dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host "`nEnabling Windows desktop..." -ForegroundColor Cyan
flutter config --enable-windows-desktop

Write-Host "`nDone! Run the app with:" -ForegroundColor Green
Write-Host "  flutter run -d windows" -ForegroundColor Yellow
Write-Host "  flutter run -d android" -ForegroundColor Yellow
