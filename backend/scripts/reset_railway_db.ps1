# Wipe user data on Railway Postgres from your PC (no Railway CLI required).
#
# 1. Railway dashboard -> Postgres service -> Variables -> copy DATABASE_URL
# 2. Run:
#      cd backend
#      .\scripts\reset_railway_db.ps1 -DatabaseUrl "postgresql://..."
#
# Options:
#   -Full          Wipe ALL data (users, customers, inventory) and re-seed super admin
#   (default)      Remove app consumer users only; keep admin/staff accounts

param(
    [Parameter(Mandatory = $true)]
    [string]$DatabaseUrl,
    [switch]$Full
)

$ErrorActionPreference = "Stop"
$backendRoot = Split-Path $PSScriptRoot -Parent
Set-Location $backendRoot

$url = $DatabaseUrl.Trim()
if ($url.StartsWith("postgres://")) {
    $url = "postgresql://" + $url.Substring("postgres://".Length)
}
if ($url.StartsWith("postgresql://") -and $url -notmatch "\+asyncpg") {
    $url = $url.Replace("postgresql://", "postgresql+asyncpg://")
}

$env:DATABASE_URL = $url

Write-Host ""
Write-Host "Target: Railway Postgres (remote)"
if ($Full) {
    Write-Host "Mode:   FULL reset (all data deleted, super admin re-created)"
    Write-Host ""
    python -m app.database.reset
} else {
    Write-Host "Mode:   Consumer users only (admin/staff kept)"
    Write-Host ""
    python -m app.database.clear_consumer_users
}

Write-Host ""
Write-Host "Done. You can sign up again in the AURUM app."
