param(
  [string]$PackageName = 'com.ghostheart5.chronospark',
  [switch]$RequireDevice
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Resolve-AdbPath {
  $command = Get-Command adb -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $candidates = @(
    (if ($env:ANDROID_SDK_ROOT) { Join-Path $env:ANDROID_SDK_ROOT 'platform-tools/adb.exe' } else { $null }),
    (if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe' } else { $null }),
    (Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'),
    'C:/Android/Sdk/platform-tools/adb.exe',
    'C:/LDPlayer/LDPlayer9/adb.exe'
  ) | Where-Object { $_ -and (Test-Path $_) }

  return $candidates | Select-Object -First 1
}

function Test-AndroidDeviceConnected([string]$AdbPath) {
  & $AdbPath start-server | Out-Null
  foreach ($port in 5555..5565) {
    & $AdbPath connect ("127.0.0.1:{0}" -f $port) | Out-Null
  }

  $deviceLines = & $AdbPath devices | Select-String "\tdevice$"
  return [bool]$deviceLines
}

Write-Host 'Running strict Android runtime gate...'

$adbPath = Resolve-AdbPath
if (-not $adbPath) {
  if ($RequireDevice) {
    Write-Host 'adb not found and device is required for this gate.'
    exit 1
  }
  Write-Host 'adb not found. Skipping device runtime checks.'
  exit 0
}

$hasDevice = Test-AndroidDeviceConnected -AdbPath $adbPath
if (-not $hasDevice) {
  if ($RequireDevice) {
    Write-Host 'No Android device/emulator detected, but device is required.'
    exit 1
  }

  Write-Host 'No Android device/emulator detected. Skipping runtime diagnostics.'
  exit 0
}

Write-Host 'Device detected. Running Android one-click diagnose...'
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/android_diagnose_one_click.ps1') -PackageName $PackageName
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Android diagnose one-click failed.'
  exit $LASTEXITCODE
}

Write-Host 'Running latest Android logcat scan...'
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/android_logcat_scan_latest.ps1')
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Android logcat scan task failed.'
  exit $LASTEXITCODE
}

$latestLog = Get-ChildItem -Path logs -Filter 'android-logcat-*.log' -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $latestLog) {
  Write-Host 'No runtime log produced after diagnose. Treating as failure.'
  exit 1
}

Write-Host "Strict app-marker scan log: $($latestLog.FullName)"

$appFatalPatterns = @(
  "Process\s+$([regex]::Escape($PackageName))\s+has died",
  "ANR in\s+$([regex]::Escape($PackageName))",
  "Unable to start.*$([regex]::Escape($PackageName))",
  'E/flutter',
  'FATAL EXCEPTION'
)

$hits = Select-String -Path $latestLog.FullName -Pattern $appFatalPatterns -CaseSensitive:$false -Context 2,4

if (-not $hits) {
  Write-Host 'No app fatal runtime markers found.'
  Write-Host 'STRICT ANDROID RUNTIME GATE PASSED' -ForegroundColor Green
  exit 0
}

# Keep only entries that are clearly app-related when marker is generic.
$appHits = @()
foreach ($hit in $hits) {
  $line = $hit.Line
  $contextBlock = @($hit.Context.PreContext + $hit.Context.PostContext) -join "`n"

  if ($line -match 'E/flutter') {
    $appHits += $hit
    continue
  }

  if ($line -match [regex]::Escape($PackageName) -or $contextBlock -match [regex]::Escape($PackageName)) {
    $appHits += $hit
    continue
  }
}

if ($appHits.Count -eq 0) {
  Write-Host 'No app-specific fatal markers found after filtering generic system noise.'
  Write-Host 'STRICT ANDROID RUNTIME GATE PASSED' -ForegroundColor Green
  exit 0
}

Write-Host ''
Write-Host ("App-specific fatal marker count: " + $appHits.Count) -ForegroundColor Red
$appHits | Select-Object -First 20 | ForEach-Object {
  Write-Host '---' -ForegroundColor Red
  $_.Context.PreContext | ForEach-Object { Write-Host $_ }
  Write-Host $_.Line -ForegroundColor Red
  $_.Context.PostContext | ForEach-Object { Write-Host $_ }
}

Write-Host ''
Write-Host 'STRICT ANDROID RUNTIME GATE FAILED' -ForegroundColor Red
exit 1
