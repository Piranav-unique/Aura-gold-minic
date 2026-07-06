# Run the FastAPI backend against local Docker Postgres (not Railway).
# Usage:  cd backend; .\scripts\run_local.ps1

$ErrorActionPreference = "Stop"
$backendRoot = Split-Path $PSScriptRoot -Parent
Set-Location $backendRoot

Write-Host "Starting local Postgres (port 5435)..."
docker compose up -d db

Write-Host "Waiting for Postgres..."
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    $status = docker inspect -f "{{.State.Health.Status}}" ags-gold-db 2>$null
    if ($status -eq "healthy") { $ready = $true; break }
    Start-Sleep -Seconds 1
}
if (-not $ready) {
    Write-Warning "Postgres health check timed out; continuing anyway..."
}

Write-Host "Running migrations..."
$env:PYTHONPATH = "."
python -m alembic upgrade head

Write-Host ""
Write-Host "API:  http://localhost:8000/docs"
Write-Host "Health: http://localhost:8000/health"
Write-Host "Local OTP dev code (if SMS fails): see SIGNUP_OTP_DEV_CODE in .env"
Write-Host ""
Write-Host "Press Ctrl+C to stop the server."
Write-Host ""

python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
