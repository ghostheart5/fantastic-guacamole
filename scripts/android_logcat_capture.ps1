param(
  [string]$PackageName = 'com.ghostheart5.chronospark'
)

$ErrorActionPreference = 'Stop'

function Resolve-AdbCandidates {
  $sdkRoot = if ($env:ANDROID_SDK_ROOT) { Join-Path $env:ANDROID_SDK_ROOT 'platform-tools/adb.exe' } else { $null }
  $homeRoot = if ($env:ANDROID_HOME) { Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe' } else { $null }
  $localSdk = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'

  $candidates = @(
    (Get-Command adb -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    $sdkRoot,
    $homeRoot,
    $localSdk,
    'C:/Android/Sdk/platform-tools/adb.exe',
    'C:/LDPlayer/LDPlayer9/adb.exe'
  ) | Where-Object { $_ -and (Test-Path $_) }

  return $candidates | Select-Object -Unique
}

function Resolve-AdbPath {
  $candidates = Resolve-AdbCandidates
  foreach ($candidate in $candidates) {
    & $candidate start-server | Out-Null
    foreach ($port in 5555..5565) {
      & $candidate connect ("127.0.0.1:{0}" -f $port) | Out-Null
    }
    $deviceLines = & $candidate devices | Select-String "\tdevice$"
    if ($deviceLines) {
      return $candidate
    }
  }
  return $candidates | Select-Object -First 1
}

$adb = Resolve-AdbPath
if (-not $adb) {
  Write-Host 'adb was not found. Install Android platform-tools or set ANDROID_SDK_ROOT/ANDROID_HOME.'
  exit 1
}

New-Item -ItemType Directory -Force -Path logs | Out-Null
$ts = Get-Date -Format yyyyMMdd-HHmmss
$file = Join-Path logs ("android-logcat-$ts.log")

Write-Host 'Starting adb server...'
& $adb start-server | Out-Null

# Emulator and LDPlayer commonly expose adb over localhost TCP ports.
foreach ($port in 5555..5565) {
  & $adb connect ("127.0.0.1:{0}" -f $port) | Out-Null
}

$deviceLines = & $adb devices | Select-String "\tdevice$"
if (-not $deviceLines) {
  Write-Host 'No Android device/emulator detected. Start one, then re-run this task.'
  exit 1
}

$connectedDevices = $deviceLines | ForEach-Object { ($_.Line -split "\s+")[0] }
$preferredDevice = @('emulator-5554', '127.0.0.1:5555') | Where-Object { $connectedDevices -contains $_ } | Select-Object -First 1
$deviceSerial = if ($preferredDevice) { $preferredDevice } else { $connectedDevices | Select-Object -First 1 }
Write-Host "Using device/emulator: $deviceSerial"

Write-Host "Using package hint: $PackageName"
Write-Host 'Clearing logcat buffer...'
& $adb -s $deviceSerial logcat -c

Write-Host "Capturing logcat to: $file"
Write-Host 'Reproduce the issue, then press Ctrl+C to stop capture.'
& $adb -s $deviceSerial logcat -v time *:V | Tee-Object -FilePath $file
