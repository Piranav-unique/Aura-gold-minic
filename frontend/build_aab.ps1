# Build Android App Bundle (.aab) for Google Play — uses hosted Railway API by default.
param(
    [string]$ApiBaseUrl = "https://aura-gold-minic-production.up.railway.app/api/v1"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Building app bundle (AAB)..." -ForegroundColor Cyan
Write-Host "API: $ApiBaseUrl" -ForegroundColor DarkGray

# Regenerate plugins without dev-only integration_test (breaks release Java compile).
flutter pub get | Out-Null
$registrant = Join-Path $PSScriptRoot "android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java"
if (Test-Path $registrant) {
    $content = Get-Content $registrant -Raw
    $content = $content -replace '(?s)\s*try \{\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*\} catch \(Exception e\) \{\s*Log\.e\(TAG, "Error registering plugin integration_test.*?\);\s*\}', ''
    Set-Content -Path $registrant -Value $content -NoNewline
}

$buildArgs = @(
    "build", "appbundle", "--release",
    "--dart-define=ENV=prod",
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=API_LOGS_ONLY=false"
)

flutter @buildArgs

$pubspec = Get-Content (Join-Path $PSScriptRoot "pubspec.yaml") | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
if ($pubspec) {
    Write-Host ""
    Write-Host "Release version: $($pubspec.Trim())" -ForegroundColor Yellow
}

$aab = Join-Path $PSScriptRoot "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aab) {
    Write-Host ""
    Write-Host "AAB ready:" -ForegroundColor Green
    Write-Host $aab
    Write-Host ""
    Write-Host "Upload this file to Google Play Console." -ForegroundColor Cyan
} else {
    Write-Error "AAB was not created."
}
