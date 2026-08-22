param(
  [ValidateSet('maestro', 'maestro-onboarding', 'staging', 'production')]
  [string]$Profile = 'maestro',

  [ValidateSet('pr-smoke', 'nightly-feature-e2e', 'pre-release-full', 'sandbox-subscriptions')]
  [string]$Level = 'pr-smoke',
  [string]$Suite,
  [string]$Device = 'emulator-5554',
  [switch]$SkipBuild,
  [switch]$PreserveTestState,
  [switch]$ReinstallDriver
)

$ErrorActionPreference = 'Stop'

$profiles = @{
  maestro = @{
    AppId = 'com.ghostheart5.chronospark.maestro'
    GradleProfile = 'maestro'
    Flavor = 'tester'
    MaestroMode = 'true'
    MockLogin = 'true'
  }
  'maestro-onboarding' = @{
    AppId = 'com.ghostheart5.chronospark.maestro'
    GradleProfile = 'maestro'
    Flavor = 'tester'
    MaestroMode = 'false'
    MockLogin = 'true'
  }
  staging = @{
    AppId = 'com.ghostheart5.chronospark.staging'
    GradleProfile = 'staging'
    Flavor = 'staging'
    MaestroMode = 'false'
    MockLogin = 'false'
  }
  production = @{
    AppId = 'com.ghostheart5.chronospark'
    GradleProfile = 'production'
    Flavor = 'prod'
    MaestroMode = 'false'
    MockLogin = 'false'
  }
}

$levels = @{
  'pr-smoke' = @{
    Suite = 'maestro/levels/pr_smoke.yaml'
    AllowedProfiles = @('maestro')
  }
  'nightly-feature-e2e' = @{
    Suite = 'maestro/levels/nightly_feature_e2e.yaml'
    AllowedProfiles = @('maestro', 'maestro-onboarding')
  }
  'pre-release-full' = @{
    Suite = 'maestro/levels/pre_release_full_validation.yaml'
    AllowedProfiles = @('maestro-onboarding')
  }
  'sandbox-subscriptions' = @{
    Suite = 'maestro/levels/sandbox_subscription_validation.yaml'
    AllowedProfiles = @('maestro')
  }
}

$selected = $profiles[$Profile]
$usesLevel = [string]::IsNullOrWhiteSpace($Suite)
if ($usesLevel) {
  $Suite = $levels[$Level].Suite
}
if (!(Test-Path -LiteralPath $Suite)) {
  throw "Maestro suite '$Suite' does not exist."
}
if ($usesLevel -and $levels.ContainsKey($Level) -and $profiles.ContainsKey($Profile) -and
     $levels[$Level].AllowedProfiles -notcontains $Profile)) {
  throw "Execution level '$Level' cannot run with profile '$Profile'."
}
$email = $env:MAESTRO_EMAIL
$password = $env:MAESTRO_PASSWORD

if ($Profile -in @('maestro', 'maestro-onboarding')) {
  if ([string]::IsNullOrWhiteSpace($email)) { $email = 'mock@chronospark.app' }
  if ([string]::IsNullOrWhiteSpace($password)) { $password = 'ChronoSpark123!' }
} elseif ([string]::IsNullOrWhiteSpace($email) -or [string]::IsNullOrWhiteSpace($password)) {
  throw 'MAESTRO_EMAIL and MAESTRO_PASSWORD are required for staging and production probes.'
}

$adbCommand = (Get-Command adb -ErrorAction SilentlyContinue).Source
if ([string]::IsNullOrWhiteSpace($adbCommand)) {
  $adbCommand = 'C:\Android\Sdk\platform-tools\adb.exe'
}
if (!(Test-Path $adbCommand) -and !(Get-Command $adbCommand -ErrorAction SilentlyContinue)) {
  throw 'ADB was not found. Add Android platform-tools to PATH.'
}

& $adbCommand -s $Device get-state | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Android device '$Device' is not available." }

if ($Profile -in @('maestro', 'maestro-onboarding')) {
  # Android 14+ emulator images can display a first-use handwriting tutorial
  # over text fields. It belongs to the system IME, not ChronoSpark, and makes
  # coordinate-independent UI tests nondeterministic.
  & $adbCommand -s $Device shell settings put secure stylus_handwriting_enabled 0 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Could not disable the emulator stylus handwriting tutorial.'
  }
  & $adbCommand -s $Device shell input keyevent 4 | Out-Null
}

if (!$SkipBuild) {
  $env:CHRONOSPARK_BUILD_PROFILE = $selected.GradleProfile
  $env:ORG_GRADLE_PROJECT_CHRONOSPARK_BUILD_PROFILE = $selected.GradleProfile
  $buildArguments = @(
    'build', 'apk', '--debug',
    "--android-project-arg=CHRONOSPARK_BUILD_PROFILE=$($selected.GradleProfile)",
    "--dart-define=CHRONOSPARK_APP_FLAVOR=$($selected.Flavor)",
    "--dart-define=CHRONOSPARK_MAESTRO_MODE=$($selected.MaestroMode)",
    "--dart-define=CHRONOSPARK_ENABLE_MOCK_LOGIN=$($selected.MockLogin)",
    "--dart-define=CHRONOSPARK_ENABLE_MOCK_MODE=false",
    "--dart-define=CHRONOSPARK_PAYWALL_DISABLED=false",
    "--dart-define=CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS=false"
  )
  & flutter @buildArguments
  if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed.' }

  $aaptCommand = Get-ChildItem "$env:ANDROID_HOME\build-tools" -Recurse -Filter aapt* -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in @('aapt', 'aapt.exe') } |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
  if ($aaptCommand) {
    $badging = & $aaptCommand dump badging 'build/app/outputs/flutter-apk/app-debug.apk' | Select-Object -First 1
    if ($badging -notmatch "package: name='$([regex]::Escape($selected.AppId))'") {
      throw "Built APK package does not match expected profile app id '$($selected.AppId)'."
    }
  }

  & $adbCommand -s $Device install -r 'build/app/outputs/flutter-apk/app-debug.apk'
  if ($LASTEXITCODE -ne 0) { throw 'APK installation failed.' }
}

if (!$PreserveTestState) {
  if ($Profile -notin @('maestro', 'maestro-onboarding')) {
    throw 'Only isolated Maestro profiles may be reset automatically.'
  }
  & $adbCommand -s $Device shell pm clear $selected.AppId | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Could not reset isolated test package '$($selected.AppId)'."
  }
}

$safeSuiteName = [IO.Path]::GetFileNameWithoutExtension($Suite)
$artifactRoot = "artifacts/maestro/$Profile/$safeSuiteName"
New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
$resultPath = Join-Path $artifactRoot 'results.xml'
if (Test-Path -LiteralPath $resultPath) {
  Remove-Item -LiteralPath $resultPath -Force
}

& $adbCommand -s $Device logcat -c | Out-Null

$maestroArguments = @(
  '--device', $Device,
  'test', $Suite,
  '-e', "APP_ID=$($selected.AppId)",
  '-e', "MAESTRO_EMAIL=$email",
  '-e', "MAESTRO_PASSWORD=$password",
  '--debug-output', "$artifactRoot/debug",
  '--flatten-debug-output',
  '--format', 'junit',
  '--output', $resultPath,
  '--no-ansi'
)
if ($ReinstallDriver) { $maestroArguments += '--reinstall-driver' }

try {
  & maestro @maestroArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Maestro suite failed with exit code $LASTEXITCODE. See $artifactRoot."
  }
  if (!(Test-Path -LiteralPath $resultPath)) {
    throw "Maestro did not write the expected JUnit result: $resultPath"
  }
  [xml]$junit = Get-Content -LiteralPath $resultPath -Raw
  $failedCases = @($junit.SelectNodes('//testcase[failure or error]'))
  if ($failedCases.Count -eq 0) {
    Write-Host 'Maestro JUnit report contains no failed test cases.'
  } else {
    throw "Maestro JUnit report contains $($failedCases.Count) failed test case(s). See $resultPath."
  }
} finally {
  # These artifacts contain device diagnostics only. They are never baselines.
  & $adbCommand -s $Device logcat -d -t 300 | Out-File -LiteralPath (Join-Path $artifactRoot 'device-logcat.txt') -Encoding utf8
  & $adbCommand -s $Device exec-out screencap -p | Set-Content -LiteralPath (Join-Path $artifactRoot 'device-final.png') -AsByteStream
}

Write-Host "Maestro $Profile $Level suite passed: $Suite" -ForegroundColor Green
