# Build Android App Bundle (.aab) for Google Play Store upload.
param(
    [string]$ApiBaseUrl = ""
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Building app bundle (AAB)..." -ForegroundColor Cyan
if ($ApiBaseUrl) {
    Write-Host "API: $ApiBaseUrl" -ForegroundColor DarkGray
} else {
    Write-Host "API: Railway hosted (default)" -ForegroundColor DarkGray
}

$buildArgs = @("build", "appbundle", "--release")
if ($ApiBaseUrl) {
    $buildArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
}

flutter @buildArgs

$aab = Join-Path $PSScriptRoot "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aab) {
    Write-Host ""
    Write-Host "AAB ready:" -ForegroundColor Green
    Write-Host $aab
} else {
    Write-Error "AAB was not created."
}
