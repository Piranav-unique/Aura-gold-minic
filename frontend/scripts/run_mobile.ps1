# Run on device; terminal shows ONLY [API] lines (no FlutterJNI / install noise).
param(
    [string]$Device = "192.168.0.12:42889",
    [string]$ApiBaseUrl = "",
    [switch]$Cloud,
    [string]$ApiHost = ""
)

& (Join-Path $PSScriptRoot "..\run.ps1") @PSBoundParameters
