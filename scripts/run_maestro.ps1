param(
  [ValidateSet('maestro', 'maestro-onboarding', 'staging', 'production')]
  [string]$Profile = 'maestro',

  [string]$Suite = 'maestro/smoke/_suite_smoke.yaml',
  [string]$Device = 'emulator-5554',
  [switch]$SkipBuild,
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

$selected = $profiles[$Profile]
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

$safeSuiteName = [IO.Path]::GetFileNameWithoutExtension($Suite)
$artifactRoot = "artifacts/maestro/$Profile/$safeSuiteName"
New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
$resultPath = Join-Path $artifactRoot 'results.xml'
if (Test-Path -LiteralPath $resultPath) {
  Remove-Item -LiteralPath $resultPath -Force
}

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

& maestro @maestroArguments
$maestroExitCode = $LASTEXITCODE
if ($maestroExitCode -ne 0) {
  $junitSucceeded = $false
  if (Test-Path -LiteralPath $resultPath) {
    try {
      [xml]$junit = Get-Content -LiteralPath $resultPath -Raw
      $suiteNodes = @($junit.testsuites.testsuite)
      $testCount = 0
      $failureCount = 0
      $errorCount = 0
      foreach ($suiteNode in $suiteNodes) {
        $testCount += [int]$suiteNode.tests
        $failureCount += [int]$suiteNode.failures
        if ($null -ne $suiteNode.errors) {
          $errorCount += [int]$suiteNode.errors
        }
      }
      $failedCases = @(
        $junit.SelectNodes(
          '//testcase[failure or error or @status="ERROR" or @status="FAILED"]'
        )
      )
      $junitSucceeded =
        $testCount -gt 0 -and
        $failureCount -eq 0 -and
        $errorCount -eq 0 -and
        $failedCases.Count -eq 0
    } catch {
      Write-Warning "Maestro JUnit result could not be validated: $($_.Exception.Message)"
    }
  }

  if (!$junitSucceeded) {
    throw "Maestro suite failed. See $artifactRoot."
  }

  Write-Warning (
    "Maestro exited with code $maestroExitCode after writing a complete " +
    'zero-failure JUnit report; accepting the report as authoritative.'
  )
}

Write-Host "Maestro $Profile suite passed: $Suite" -ForegroundColor Green
