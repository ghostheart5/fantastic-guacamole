$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]
$requiredTargetApi = 36
$powerShellCommand = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }

function Add-Failure([string]$message) {
  $script:failures.Add($message)
}

Write-Host 'Running ChronoSpark release guard checks...'

function Get-RegexIntegerValue([string]$Text, [string]$Pattern) {
  $m = [regex]::Match($Text, $Pattern)
  if (-not $m.Success) {
    return $null
  }
  return [int]$m.Groups[1].Value
}

$manifest = Join-Path $root 'android/app/src/main/AndroidManifest.xml'
if (-not (Test-Path $manifest)) {
  Add-Failure "Missing AndroidManifest.xml: $manifest"
} else {
  $manifestContent = Get-Content -Path $manifest -Raw

  if ($manifestContent -notmatch 'android:usesCleartextTraffic="false"') {
    Add-Failure 'AndroidManifest application tag must set android:usesCleartextTraffic="false".'
  }

  $allowedPermissions = @(
    'android.permission.INTERNET',
    'com.android.vending.BILLING',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.RECORD_AUDIO',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_DATA_SYNC',
    'android.permission.FOREGROUND_SERVICE_MICROPHONE',
    'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    'android.permission.WAKE_LOCK',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.SCHEDULE_EXACT_ALARM'
  )

  $permissionMatches = [regex]::Matches(
    $manifestContent,
    '<uses-permission\b[^>]*android:name="([^"]+)"[^>]*/?>'
  )
  foreach ($pm in $permissionMatches) {
    $permissionName = $pm.Groups[1].Value
    $declaration = $pm.Value
    if ($declaration -match 'tools:node="remove"') {
      continue
    }
    if ($allowedPermissions -notcontains $permissionName) {
      Add-Failure "Unexpected Android permission declared: $permissionName"
    }
  }
}

$androidGradle = Join-Path $root 'android/app/build.gradle.kts'
if (-not (Test-Path $androidGradle)) {
  Add-Failure "Missing Android build script: $androidGradle"
} else {
  $gradleContent = Get-Content -Path $androidGradle -Raw

  $compileSdk = Get-RegexIntegerValue -Text $gradleContent -Pattern 'compileSdk\s*=\s*maxOf\(flutter\.compileSdkVersion,\s*(\d+)\)'
  if ($null -eq $compileSdk -or $compileSdk -lt $requiredTargetApi) {
    Add-Failure "compileSdk floor must be >= $requiredTargetApi for the 2026-08-31 Google Play policy change."
  }

  $targetSdk = Get-RegexIntegerValue -Text $gradleContent -Pattern 'targetSdk\s*=\s*maxOf\(flutter\.targetSdkVersion,\s*(\d+)\)'
  if ($null -eq $targetSdk -or $targetSdk -lt $requiredTargetApi) {
    Add-Failure "targetSdk floor must be >= $requiredTargetApi for the 2026-08-31 Google Play policy change."
  }

  if ($gradleContent -notmatch '(?:id\(|apply\(plugin\s*=\s*)"com\.google\.firebase\.crashlytics"') {
    Add-Failure 'android/app/build.gradle.kts must apply Firebase Crashlytics plugin.'
  }

  if ($gradleContent -notmatch '(?:id\(|apply\(plugin\s*=\s*)"com\.google\.gms\.google-services"') {
    Add-Failure 'android/app/build.gradle.kts must apply Google services plugin.'
  }
}

$firebaseOptions = Join-Path $root 'lib/firebase_options.dart'
if (-not (Test-Path $firebaseOptions)) {
  Add-Failure "Missing firebase_options.dart: $firebaseOptions"
} else {
  $firebaseContent = Get-Content -Path $firebaseOptions -Raw
  if ($firebaseContent -match "iosBundleId:\s*'com\.example\.chronospark'") {
    Add-Failure 'firebase_options.dart still contains the retired com.example.chronospark macOS identity.'
  }
}

$mainEntrypoint = Join-Path $root 'lib/main.dart'
if (-not (Test-Path $mainEntrypoint)) {
  Add-Failure "Missing main entrypoint: $mainEntrypoint"
} else {
  $mainContent = Get-Content -Path $mainEntrypoint -Raw
  $startupContent = $mainContent
  $bootstrapPath = Join-Path $root 'lib/app/startup/app_bootstrap.dart'
  if ($mainContent -match "app/startup/app_bootstrap\.dart" -and (Test-Path $bootstrapPath)) {
    $startupContent += "`n" + (Get-Content -Path $bootstrapPath -Raw)
  }

  if ($startupContent -notmatch 'runZonedGuarded\s*\(') {
    Add-Failure 'The main startup path must wrap startup with runZonedGuarded.'
  }
  if ($startupContent -notmatch 'FlutterError\.onError\s*=') {
    Add-Failure 'The main startup path must assign FlutterError.onError for framework crash capture.'
  }
  if ($startupContent -notmatch 'PlatformDispatcher\.instance\.onError\s*=') {
    Add-Failure 'The main startup path must assign PlatformDispatcher.instance.onError for isolate/dispatcher crash capture.'
  }
}

$pubspec = Join-Path $root 'pubspec.yaml'
if (Test-Path $pubspec) {
  $pubspecContent = Get-Content -Path $pubspec -Raw
  $pubspecLines = Get-Content -Path $pubspec
  if ($pubspecContent -notmatch 'firebase_core') {
    Add-Failure 'pubspec.yaml missing firebase_core dependency.'
  }

  $currentSection = ''
  $integrationInDependencies = $false
  $integrationInDevDependencies = $false

  foreach ($line in $pubspecLines) {
    $trimmed = $line.TrimEnd()

    if ($trimmed -match '^([A-Za-z0-9_]+):\s*$') {
      $currentSection = $matches[1]
      continue
    }

    if ($trimmed -match '^\s{2,}integration_test\s*:') {
      if ($currentSection -eq 'dependencies') {
        $integrationInDependencies = $true
      }
      if ($currentSection -eq 'dev_dependencies') {
        $integrationInDevDependencies = $true
      }
    }
  }

  if ($integrationInDependencies) {
    Add-Failure 'integration_test must not be declared under dependencies; use dev_dependencies only.'
  }

  if (-not $integrationInDevDependencies) {
    Add-Failure 'integration_test should be declared under dev_dependencies for test-only usage.'
  }
} else {
  Add-Failure "Missing pubspec.yaml: $pubspec"
}

$versionGuard = Join-Path $root 'scripts/version_consistency_guard.ps1'
if (Test-Path $versionGuard) {
  & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File $versionGuard
  if ($LASTEXITCODE -ne 0) { Add-Failure 'Version consistency guard failed.' }
} else {
  Add-Failure "Missing version consistency guard: $versionGuard"
}

if ($failures.Count -gt 0) {
  Write-Host ''
  Write-Host 'Release guard failed:' -ForegroundColor Red
  foreach ($failure in $failures) {
    Write-Host " - $failure" -ForegroundColor Red
  }
  exit 1
}

Write-Host 'Release guard passed.' -ForegroundColor Green
exit 0
