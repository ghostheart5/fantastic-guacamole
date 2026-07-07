param(
    [string]$PackageName = 'com.ghostheart5.chronospark',
    [string]$DeviceId = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Resolve-CommandPath {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        return $null
    }
    return $cmd.Source
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$logsRoot = Join-Path $repoRoot 'logs/repro'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$sessionDir = Join-Path $logsRoot $timestamp

$flutterPath = Resolve-CommandPath -Name 'flutter'
$adbPath = Resolve-CommandPath -Name 'adb'

if (-not $flutterPath) {
    Write-Host 'flutter was not found on PATH.'
    exit 1
}
if (-not $adbPath) {
    Write-Host 'adb was not found on PATH.'
    exit 1
}

$flutterOut = Join-Path $sessionDir 'flutter_stdout.log'
$flutterErr = Join-Path $sessionDir 'flutter_stderr.log'
$adbOut = Join-Path $sessionDir 'adb_errors.log'
$adbErr = Join-Path $sessionDir 'adb_errors_stderr.log'

$flutterArgs = @('run')
if ($DeviceId.Trim().Length -gt 0) {
    $flutterArgs += @('-d', $DeviceId.Trim())
}

$adbArgs = @(
    'logcat',
    '-v',
    'threadtime',
    'AndroidRuntime:E',
    'flutter:E',
    'ActivityManager:E',
    '*:S'
)

Write-Host "Package: $PackageName"
Write-Host "Session: $sessionDir"
Write-Host "flutter: $flutterPath $($flutterArgs -join ' ')"
Write-Host "adb: $adbPath $($adbArgs -join ' ')"

if ($DryRun) {
    Write-Host 'Dry run only. No processes started.'
    exit 0
}

New-Item -ItemType Directory -Force -Path $sessionDir | Out-Null

& $adbPath logcat -c | Out-Null

$adbProcess = Start-Process -FilePath $adbPath -ArgumentList $adbArgs -PassThru -RedirectStandardOutput $adbOut -RedirectStandardError $adbErr
$flutterProcess = Start-Process -FilePath $flutterPath -ArgumentList $flutterArgs -PassThru -RedirectStandardOutput $flutterOut -RedirectStandardError $flutterErr -WorkingDirectory $repoRoot

$session = [ordered]@{
    timestamp       = $timestamp
    packageName     = $PackageName
    deviceId        = $DeviceId
    sessionDir      = $sessionDir
    flutterPid      = $flutterProcess.Id
    adbPid          = $adbProcess.Id
    flutterStdout   = $flutterOut
    flutterStderr   = $flutterErr
    adbErrors       = $adbOut
    adbErrorsStderr = $adbErr
    createdAtUtc    = (Get-Date).ToUniversalTime().ToString('o')
}

$sessionJson = $session | ConvertTo-Json -Depth 5
$activeSessionFile = Join-Path $logsRoot 'active_capture.json'
$sessionFile = Join-Path $sessionDir 'capture_session.json'
Set-Content -Path $activeSessionFile -Value $sessionJson -Encoding UTF8
Set-Content -Path $sessionFile -Value $sessionJson -Encoding UTF8

Write-Host ''
Write-Host 'Capture started.'
Write-Host "Flutter PID: $($flutterProcess.Id)"
Write-Host "ADB PID: $($adbProcess.Id)"
Write-Host "Active session file: $activeSessionFile"
Write-Host 'When done reproducing, run: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/repro_capture_stop.ps1'
