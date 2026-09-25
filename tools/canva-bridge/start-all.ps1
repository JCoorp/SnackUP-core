$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Start-Process powershell -ArgumentList "-NoExit","-Command","Set-Location '$PSScriptRoot'; npm run daemon"
$vendor = Join-Path $PSScriptRoot ".vendor\canva-apps-sdk-starter-kit"
if (Test-Path $vendor) {
  Start-Process powershell -ArgumentList "-NoExit","-Command","Set-Location '$vendor'; npm run start:example chatgpt_canva_bridge"
}
Write-Host "Canva Bridge iniciado." -ForegroundColor Green
