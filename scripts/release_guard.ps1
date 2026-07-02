$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$message) {
  $script:failures.Add($message)
}

Write-Host 'Running ChronoSpark release guard checks...'

$androidRegistrant = Join-Path $root 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'
if (Test-Path $androidRegistrant) {
  $content = Get-Content -Path $androidRegistrant -Raw
  if ($content -match 'integration_test') {
    Add-Failure "Release registrant includes integration_test plugin: $androidRegistrant"
  }
} else {
  Add-Failure "Missing Android plugin registrant: $androidRegistrant"
}

$manifest = Join-Path $root 'android/app/src/main/AndroidManifest.xml'
if (-not (Test-Path $manifest)) {
  Add-Failure "Missing AndroidManifest.xml: $manifest"
}

$firebaseOptions = Join-Path $root 'lib/firebase_options.dart'
if (-not (Test-Path $firebaseOptions)) {
  Add-Failure "Missing firebase_options.dart: $firebaseOptions"
}

$pubspec = Join-Path $root 'pubspec.yaml'
if (Test-Path $pubspec) {
  $pubspecContent = Get-Content -Path $pubspec -Raw
  if ($pubspecContent -notmatch 'firebase_core') {
    Add-Failure 'pubspec.yaml missing firebase_core dependency.'
  }
} else {
  Add-Failure "Missing pubspec.yaml: $pubspec"
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
