# Single command: flutter run on device; console shows [API] and [APP_EVENT] lines.
param(
    [string]$Device = "192.168.0.12:42889",
    # Leave empty to use hosted Railway API baked into the app (see env_config.dart).
    [string]$ApiBaseUrl = ""
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$flutterArgs = @("run", "-d", $Device, "--dart-define=API_LOGS_ONLY=true")
if ($ApiBaseUrl) {
    $flutterArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
}

flutter @flutterArgs `
    2>&1 | ForEach-Object {
        $line = "$_"
        if ($line -match '\[API\]' -or $line -match '\[APP_EVENT\]') {
            Write-Output $line
        }
    }
