$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "=== SnackUp Canva Bridge - setup ===" -ForegroundColor Cyan
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "Node.js 22+ no está instalado." }

if (-not (Test-Path ".env")) {
  Copy-Item ".env.example" ".env"
  Write-Host "Se creó .env. Ábrelo y completa CANVA_CLIENT_ID, CANVA_CLIENT_SECRET y GITHUB_TOKEN." -ForegroundColor Yellow
  notepad.exe ".env"
  Read-Host "Cuando termines de guardar .env, presiona Enter"
}

New-Item -ItemType Directory -Force -Path ".data","inbox","outbox",".vendor" | Out-Null

Write-Host "Verificando código..." -ForegroundColor Cyan
npm run check

Write-Host "Iniciando servidor OAuth..." -ForegroundColor Cyan
$oauth = Start-Process -FilePath "node" -ArgumentList "bridge.mjs","oauth" -PassThru
Start-Sleep -Seconds 2
Start-Process "http://127.0.0.1:8787/auth/start"
Write-Host "Autoriza Canva en el navegador. Cuando veas 'Canva conectado', vuelve aquí." -ForegroundColor Yellow
Read-Host "Presiona Enter después de autorizar Canva"
if ($oauth -and -not $oauth.HasExited) { Stop-Process -Id $oauth.Id -Force }

Write-Host "Preparando app de edición dentro de Canva..." -ForegroundColor Cyan
$vendor = Join-Path $PSScriptRoot ".vendor\canva-apps-sdk-starter-kit"
if (-not (Test-Path $vendor)) {
  git clone --depth 1 https://github.com/canva-sdks/canva-apps-sdk-starter-kit.git $vendor
}
$dest = Join-Path $vendor "examples\design_interaction\chatgpt_canva_bridge"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item "$PSScriptRoot\canva-editor\*" $dest -Recurse -Force
Push-Location $vendor
npm install
Pop-Location

Write-Host "Setup local terminado." -ForegroundColor Green
Write-Host "1) Para el daemon: npm run daemon"
Write-Host "2) Para la app dentro de Canva: cd .vendor\canva-apps-sdk-starter-kit; npm run start:example chatgpt_canva_bridge"
Write-Host "3) En Canva Developer Portal, apunta Development URL a http://localhost:8080 y pulsa Preview."
