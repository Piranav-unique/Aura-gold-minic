# Build release APK that talks only to the hosted Railway backend (any phone with internet).
param(
    [string]$ApiBaseUrl = "https://api.aurumgold.co.in/api/v1"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# Auto-detect JAVA_HOME if unset or pointing to a missing path
if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    $candidate = Get-ChildItem "C:\Program Files\Microsoft" -Filter "jdk-*" -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

    if (-not $candidate -and (Test-Path "C:\Program Files\Android\Android Studio\jbr")) {
        $candidate = "C:\Program Files\Android\Android Studio\jbr"
    }

    if ($candidate) {
        $env:JAVA_HOME = $candidate
        $env:Path = "$candidate\bin;$env:Path"
        Write-Host "Set JAVA_HOME to: $candidate" -ForegroundColor DarkCyan
    }
}

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
