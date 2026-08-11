param(
  [string]$DeviceId = '',
  [string]$RunId = 'local'
)

$ErrorActionPreference = 'Stop'
$packageId = 'com.ghostheart5.chronospark.maestro'
$adbPath = Get-Command adb -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $adbPath) {
  $sdkRoot = $env:ANDROID_SDK_ROOT
  if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_HOME }
  if ($sdkRoot) {
    $candidate = Join-Path $sdkRoot 'platform-tools/adb.exe'
    if (Test-Path -LiteralPath $candidate) { $adbPath = $candidate }
  }
}
if (-not $adbPath) {
  throw 'adb is required. Install Android platform-tools and connect a non-production emulator or physical device.'
}
$patrolPath = Get-Command patrol -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $patrolPath) {
  throw 'Patrol CLI is required. Install the approved Patrol CLI before running device E2E.'
}
$env:Path = "$(Split-Path -Parent $adbPath);$env:Path"

function Invoke-PatrolTarget {
  param(
    [Parameter(Mandatory = $true)][string]$Target,
    [string[]]$ExtraArgs = @()
  )

  & $patrolPath test --device $device --target $Target @defines @ExtraArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Patrol target failed: $Target (exit $LASTEXITCODE)."
  }
}

$devices = & $adbPath devices | Select-String -Pattern "`tdevice$" | ForEach-Object { ($_ -split "`t")[0] }
if ($DeviceId) { $devices = @($DeviceId) }
if ($devices.Count -ne 1) {
  throw "Exactly one test device is required; found $($devices.Count)."
}

$device = $devices[0]
$model = (& $adbPath -s $device shell getprop ro.product.model).Trim()
$api = (& $adbPath -s $device shell getprop ro.build.version.sdk).Trim()
$artifactRoot = Join-Path 'artifacts/device-e2e' (Get-Date -Format 'yyyyMMdd-HHmmss')
New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
@{ device = $device; model = $model; androidApi = $api; packageId = $packageId; runId = $RunId } |
  ConvertTo-Json | Set-Content (Join-Path $artifactRoot 'device-metadata.json')

$defines = @(
  '--dart-define=RUN_NATIVE_PATROL=true',
  '--dart-define=CHRONOSPARK_APP_FLAVOR=dev',
  '--dart-define=CHRONOSPARK_ENABLE_MOCK_MODE=true',
  '--dart-define=CHRONOSPARK_ENABLE_MOCK_LOGIN=true',
  '--dart-define=CHRONOSPARK_ENABLE_CLOUD_SYNC=false',
  "--dart-define=E2E_RUN_ID=$RunId",
  "--dart-define=E2E_TASK_TITLE=e2e_device_task_$RunId"
)
$env:CHRONOSPARK_BUILD_PROFILE = 'maestro'
$env:PATROL_ANALYTICS_ENABLED = 'false'

try {
  & $adbPath -s $device logcat -c
  & $adbPath -s $device shell pm path $packageId | Out-Null
  if ($LASTEXITCODE -eq 0) {
    & $adbPath -s $device shell pm clear $packageId
    if ($LASTEXITCODE -ne 0) { throw "Could not clear isolated test package $packageId." }
  }
  Invoke-PatrolTarget -Target 'integration_test/patrol_smoke_test.dart'
  Invoke-PatrolTarget -Target 'integration_test/patrol_native_app_smoke_test.dart'
  Invoke-PatrolTarget -Target 'integration_test/patrol_application_journey_test.dart'
  & $adbPath -s $device shell am force-stop $packageId
  if ($LASTEXITCODE -ne 0) { throw "Could not force-stop isolated test package $packageId." }
  Invoke-PatrolTarget -Target 'integration_test/patrol_process_restart_test.dart'
  & $adbPath -s $device shell pm revoke $packageId android.permission.POST_NOTIFICATIONS
  if ($LASTEXITCODE -ne 0) { throw 'Could not revoke notification permission on the isolated test package.' }
  Invoke-PatrolTarget -Target 'integration_test/patrol_permission_denied_test.dart'
  & $adbPath -s $device shell svc wifi disable
  & $adbPath -s $device shell svc data disable
  try {
    Invoke-PatrolTarget -Target 'integration_test/patrol_offline_state_test.dart' -ExtraArgs @('--dart-define=E2E_EXPECT_OFFLINE=true')
  }
  finally {
    & $adbPath -s $device shell svc wifi enable
    & $adbPath -s $device shell svc data enable
  }
  Invoke-PatrolTarget -Target 'integration_test/patrol_offline_state_test.dart' -ExtraArgs @('--dart-define=E2E_EXPECT_OFFLINE=false')
}
finally {
  & $adbPath -s $device logcat -d | Set-Content (Join-Path $artifactRoot 'logcat.txt')
  & $adbPath -s $device exec-out screencap -p > (Join-Path $artifactRoot 'final-screen.png')
}
