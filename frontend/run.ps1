# Run Flutter on device — defaults to LOCAL backend (not Railway).
# Usage:
#   .\run.ps1                          # local backend, auto Wi-Fi IP + device
#   .\run.ps1 -Cloud                   # Railway production API
#   .\run.ps1 -Device "192.168.0.3:38657"

param(
    [string]$Device = "",
    [string]$ApiBaseUrl = "",
    [switch]$Cloud,
    [string]$ApiHost = "",
    [switch]$Quiet,
    [switch]$VerboseLogs
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
    }
}

function Get-LanIPv4 {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL|Virtual|Hyper-V|Docker|Tailscale|VPN' -and
            $_.IPAddress -notmatch '^169\.254\.'
        } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1 -ExpandProperty IPAddress
    if ($ip) { return $ip }
    throw "Could not detect Wi-Fi/LAN IP. Pass -ApiHost manually."
}

function Resolve-FlutterDevice {
    param([string]$Requested)
    if ($Requested) { return $Requested }

    $json = flutter devices --machine 2>&1 | Out-String
    $devices = $json | ConvertFrom-Json
    $phone = $devices | Where-Object {
        $_.isSupported -and $_.targetPlatform -like 'android-*' -and -not $_.emulator
    } | Select-Object -First 1

    if ($phone) { return $phone.id }
    throw "No phone found. Connect via USB or wireless adb, then run: flutter devices"
}

if (-not $Cloud) {
    if (-not $ApiHost) {
        $ApiHost = Get-LanIPv4
    }
    if (-not $ApiBaseUrl) {
        $port = 8000
        $p8000Open = Test-NetConnection -ComputerName 127.0.0.1 -Port 8000 -InformationLevel Quiet -WarningAction SilentlyContinue
        $p8001Open = Test-NetConnection -ComputerName 127.0.0.1 -Port 8001 -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $p8000Open -and $p8001Open) {
            $port = 8001
        }
        $ApiBaseUrl = "http://${ApiHost}:${port}/api/v1"
    }
}

$Device = Resolve-FlutterDevice -Requested $Device

Write-Host ""
Write-Host "Device:     $Device"
Write-Host "API target: $(if ($ApiBaseUrl) { $ApiBaseUrl } else { 'Railway (cloud)' })"
Write-Host "Backend:    python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
Write-Host ""

Write-Host "Building and launching (first run may take 2-5 minutes)..."
if ($VerboseLogs) {
    Write-Host "Verbose Flutter logs enabled." -ForegroundColor DarkGray
} elseif (-not $Quiet) {
    Write-Host "Tip: if no logs appear over Wi-Fi, open another terminal and run: .\view_logs.ps1" -ForegroundColor DarkGray
}
Write-Host ""

$flutterArgs = @(
    "run", "-d", $Device,
    "--dart-define=API_LOGS_ONLY=true",
    "--dart-define=ADMIN_MOBILE_NUMBER=9943795005"
)
if ($VerboseLogs) {
    $flutterArgs += "--verbose"
}
if ($ApiBaseUrl) {
    $flutterArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl"
}

if ($Quiet) {
    $progressPattern = 'Launching|Gradle|gradle|assemble|Built |BUILD|Installing|Syncing files|Flutter run key|Waiting for|Debug service|VM Service|Performing hot|Application finished|Lost connection|Could not|Error:|Exception|No supported devices|Failed|error •|\[API\]|\[APP_EVENT\]|I/flutter|Running|Compiling'
    & flutter @flutterArgs 2>&1 | ForEach-Object {
        $line = "$_"
        if ($line -match $progressPattern) {
            if ($line -match 'Error:|Exception|Failed|Could not|No supported devices|error •') {
                Write-Host $line -ForegroundColor Red
            } else {
                Write-Host $line
            }
        }
    }
} else {
    & flutter @flutterArgs
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "flutter run failed (exit $LASTEXITCODE). Run 'flutter devices' to pick -Device." -ForegroundColor Red
    exit $LASTEXITCODE
}
