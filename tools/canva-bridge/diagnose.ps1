$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

Write-Host "=== SnackUp Canva Bridge - diagnóstico ===" -ForegroundColor Cyan

$ok = $true
function Check-Command($name) {
  if (Get-Command $name -ErrorAction SilentlyContinue) {
    Write-Host "[OK] $name" -ForegroundColor Green
  } else {
    Write-Host "[FALTA] $name" -ForegroundColor Red
    $script:ok = $false
  }
}

Check-Command "node"
Check-Command "npm"
Check-Command "git"

if (Test-Path ".env") {
  Write-Host "[OK] .env existe" -ForegroundColor Green
  $envText = Get-Content ".env" -Raw
  foreach ($key in @("CANVA_CLIENT_ID","CANVA_CLIENT_SECRET","GITHUB_TOKEN")) {
    if ($envText -match "(?m)^$key=.+$") {
      Write-Host "[OK] $key configurado" -ForegroundColor Green
    } else {
      Write-Host "[FALTA] $key" -ForegroundColor Red
      $ok = $false
    }
  }
} else {
  Write-Host "[FALTA] .env" -ForegroundColor Red
  $ok = $false
}

if (Test-Path ".data\canva-tokens.json") {
  Write-Host "[OK] autorización OAuth de Canva encontrada" -ForegroundColor Green
} else {
  Write-Host "[PENDIENTE] autorización OAuth de Canva" -ForegroundColor Yellow
}

if (Get-Command node -ErrorAction SilentlyContinue) {
  npm run check
  if ($LASTEXITCODE -ne 0) { $ok = $false }
}

if ($ok) {
  Write-Host "Diagnóstico base: PASS" -ForegroundColor Green
} else {
  Write-Host "Diagnóstico base: requiere atención" -ForegroundColor Yellow
}
