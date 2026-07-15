# Build release APK that talks only to the hosted Railway backend (any phone with internet).
param(
    [string]$ApiBaseUrl = "https://aura-gold-minic-production.up.railway.app/api/v1"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Building release APK..." -ForegroundColor Cyan
Write-Host "API: $ApiBaseUrl" -ForegroundColor DarkGray

flutter pub get | Out-Null
$registrant = Join-Path $PSScriptRoot "android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java"
if (Test-Path $registrant) {
    $content = Get-Content $registrant -Raw
    $content = $content -replace '(?s)\s*try \{\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*\} catch \(Exception e\) \{\s*Log\.e\(TAG, "Error registering plugin integration_test.*?\);\s*\}', ''
    Set-Content -Path $registrant -Value $content -NoNewline
}

$buildArgs = @(
    "build", "apk", "--release",
    "--dart-define=ENV=prod",
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=API_LOGS_ONLY=false",
    "--dart-define=ADMIN_MOBILE_NUMBER=9943795005"
)

flutter @buildArgs

$pubspec = Get-Content (Join-Path $PSScriptRoot "pubspec.yaml") | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
if ($pubspec) {
    Write-Host ""
    Write-Host "Release version: $($pubspec.Trim())" -ForegroundColor Yellow
    Write-Host "After uploading the APK, run:" -ForegroundColor Yellow
    Write-Host "  .\scripts\print_app_release_env.ps1" -ForegroundColor DarkGray
}

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
