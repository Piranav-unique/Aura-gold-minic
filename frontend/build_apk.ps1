# Build release APK for installing on another Android phone (same Wi-Fi as backend PC).
param(
    # Leave empty to use hosted Railway API baked into the app (see env_config.dart).
    [string]$ApiBaseUrl = ""
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Building release APK..." -ForegroundColor Cyan
if ($ApiBaseUrl) {
    Write-Host "API: $ApiBaseUrl" -ForegroundColor DarkGray
} else {
    Write-Host "API: Railway hosted (default)" -ForegroundColor DarkGray
}

$buildArgs = @("build", "apk", "--release", "--dart-define=API_LOGS_ONLY=false")
if ($ApiBaseUrl) {
    $buildArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
}

flutter @buildArgs

$apk = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
    Write-Host ""
    Write-Host "APK ready:" -ForegroundColor Green
    Write-Host $apk
    Write-Host ""
    Write-Host "Copy this file to the other phone and install it." -ForegroundColor Cyan
    Write-Host "Install on any phone with internet - API uses Railway by default." -ForegroundColor DarkGray
} else {
    Write-Error "APK was not created."
}
