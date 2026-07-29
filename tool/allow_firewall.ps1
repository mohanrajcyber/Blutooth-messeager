# Allow BT Messenger through Windows Firewall (run once as Administrator)
$exe = Join-Path $PSScriptRoot "..\build\windows\x64\runner\Debug\bluetooth_messenger.exe"
if (-not (Test-Path $exe)) {
    $exe = Join-Path $PSScriptRoot "..\build\windows\x64\runner\Release\bluetooth_messenger.exe"
}
if (-not (Test-Path $exe)) {
    Write-Host "Build the app first: flutter run -d windows"
    exit 1
}
New-NetFirewallRule -DisplayName "BT Messenger" -Direction Inbound -Program $exe -Action Allow -ErrorAction SilentlyContinue | Out-Null
Write-Host "Firewall rule added for: $exe"
