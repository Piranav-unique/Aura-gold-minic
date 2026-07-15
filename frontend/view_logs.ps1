# Stream Flutter/API logs from the phone (use when wireless run.ps1 shows no output).
param(
    [string]$Device = "",
    [switch]$All
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not $Device) {
    $json = flutter devices --machine 2>&1 | Out-String
    $devices = $json | ConvertFrom-Json
    $phone = $devices | Where-Object {
        $_.isSupported -and $_.targetPlatform -like 'android-*' -and -not $_.emulator
    } | Select-Object -First 1
    if ($phone) { $Device = $phone.id }
}

$adbArgs = @("logcat", "-v", "brief")
if ($Device) { $adbArgs = @("-s", $Device) + $adbArgs }

Write-Host "Streaming logs from: $(if ($Device) { $Device } else { 'default device' })" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray
Write-Host ""

if ($All) {
    & adb @adbArgs
} else {
    & adb @adbArgs 2>&1 | ForEach-Object {
        $line = "$_"
        if ($line -match 'I/flutter|\[API\]|\[APP_EVENT\]|flutter :|E/flutter|W/flutter') {
            Write-Host $line
        }
    }
}
