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
$buildLog = Join-Path logs ("flutter-apk-debug-$ts.log")
$runtimeLog = Join-Path logs ("android-logcat-$ts.log")

Write-Host 'Starting adb server...'
& $adb start-server | Out-Null

# Emulator and LDPlayer commonly expose adb over localhost TCP ports.
foreach ($port in 5555..5565) {
  & $adb connect ("127.0.0.1:{0}" -f $port) | Out-Null
}

$deviceLines = & $adb devices | Select-String "\tdevice$"
if (-not $deviceLines) {
  Write-Host 'No Android device/emulator detected. Start one, then rerun this task.'
  exit 1
}

$connectedDevices = $deviceLines | ForEach-Object { ($_.Line -split "\s+")[0] }
$preferredDevice = @('emulator-5554', '127.0.0.1:5555') | Where-Object { $connectedDevices -contains $_ } | Select-Object -First 1
$deviceSerial = if ($preferredDevice) { $preferredDevice } else { $connectedDevices | Select-Object -First 1 }
Write-Host "Using device/emulator: $deviceSerial"

function Get-AppPid {
  param(
    [string]$AdbPath,
    [string]$Serial,
    [string]$AppPackage,
    [int]$Attempts = 10,
    [int]$DelayMs = 300
  )

  for ($i = 0; $i -lt $Attempts; $i++) {
    $pidOutput = & $AdbPath -s $Serial shell pidof $AppPackage
    $appPid = if ($null -ne $pidOutput) { "$pidOutput".Trim() } else { '' }
    if ($appPid) {
      return $appPid
    }
    Start-Sleep -Milliseconds $DelayMs
  }

  return ''
}

Write-Host "Building debug APK with verbose logs: $buildLog"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
flutter build apk --debug -v *>&1 | Tee-Object -FilePath $buildLog
$ErrorActionPreference = $previousErrorActionPreference
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Build failed. See build log above and rerun flutter-apk-scan-latest-context.'
  exit $LASTEXITCODE
}

$apkPath = Join-Path $PWD 'build/app/outputs/flutter-apk/app-debug.apk'
if (-not (Test-Path $apkPath)) {
  Write-Host "Debug APK not found at: $apkPath"
  exit 1
}

Write-Host "Installing APK: $apkPath"
& $adb -s $deviceSerial install --no-streaming -r "$apkPath"
if ($LASTEXITCODE -ne 0) {
  Write-Host 'APK install failed.'
  exit $LASTEXITCODE
}

Write-Host 'Clearing logcat buffer...'
& $adb -s $deviceSerial logcat -c

Write-Host "Launching app with package: $PackageName"
& $adb -s $deviceSerial shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Host

$appPid = Get-AppPid -AdbPath $adb -Serial $deviceSerial -AppPackage $PackageName -Attempts 8 -DelayMs 250
if (-not $appPid) {
  Write-Host 'App process not observed after monkey launch. Retrying with am start...'
  & $adb -s $deviceSerial shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p $PackageName | Out-Host
  $appPid = Get-AppPid -AdbPath $adb -Serial $deviceSerial -AppPackage $PackageName -Attempts 12 -DelayMs 300
}

Write-Host "Dumping current logcat to: $runtimeLog"
if ($appPid) {
  Write-Host "App PID: $appPid"
  & $adb -s $deviceSerial logcat -d --pid $appPid -v time | Tee-Object -FilePath $runtimeLog | Out-Null
}
else {
  Write-Host 'App PID not found. Capturing full logcat buffer for launch diagnostics.'
  & $adb -s $deviceSerial logcat -d -v time | Tee-Object -FilePath $runtimeLog | Out-Null
}

$patterns = @(
  'FATAL EXCEPTION',
  'E/flutter',
  'ANR',
  'MissingPluginException',
  'NoSuchMethodError',
  'SocketException',
  'TimeoutException',
  'Failed assertion',
  'Process\s+' + [regex]::Escape($PackageName) + '\s+has died',
  'Unable to start.*' + [regex]::Escape($PackageName),
  'ANR in\s+' + [regex]::Escape($PackageName)
)

$hits = Select-String -Path $runtimeLog -Pattern $patterns -CaseSensitive:$false -Context 2, 4 |
Select-Object -First 60

Write-Host ''
Write-Host '=== Diagnose Summary ==='
Write-Host "Build log: $buildLog"
Write-Host "Runtime log: $runtimeLog"

if (-not $hits) {
  Write-Host 'No crash/error markers found in captured logcat dump.'
  exit 0
}

Write-Host ("Crash/error marker count: " + $hits.Count)
$hits | Select-Object -First 12 | ForEach-Object {
  Write-Host '---'
  $_.Context.PreContext | ForEach-Object { Write-Host $_ }
  Write-Host $_.Line
  $_.Context.PostContext | ForEach-Object { Write-Host $_ }
}
