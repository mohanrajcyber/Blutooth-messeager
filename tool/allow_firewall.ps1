# Allow BT Messenger through Windows Firewall (run once as Administrator)
$root = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $root "build\windows\x64\runner\Debug\bluetooth_messenger.exe"
if (-not (Test-Path $exe)) {
    $exe = Join-Path $root "build\windows\x64\runner\Release\bluetooth_messenger.exe"
}
if (-not (Test-Path $exe)) {
    Write-Host "Build the app first: flutter run -d windows"
    exit 1
}

New-NetFirewallRule -DisplayName "BT Messenger App" -Direction Inbound -Program $exe -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "BT Messenger UDP 45678" -Direction Inbound -Protocol UDP -LocalPort 45678 -Action Allow -ErrorAction SilentlyContinue | Out-Null
New-NetFirewallRule -DisplayName "BT Messenger TCP 45679" -Direction Inbound -Protocol TCP -LocalPort 45679 -Action Allow -ErrorAction SilentlyContinue | Out-Null
Write-Host "Firewall rules added for BT Messenger (app + ports 45678/45679)"
