param(
  [switch]$IncludeAndroidRuntime,
  [switch]$IncludeCoverage,
  [switch]$RequireAndroidDevice,
  [string]$AndroidPackageName = 'com.ghostheart5.chronospark'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Run-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host ""
  Write-Host "==> $Name"
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

Write-Host 'Running strict ChronoSpark gate...'

Run-Step -Name 'Flutter analyze' -Action {
  flutter analyze
}

if ($IncludeCoverage) {
  Run-Step -Name 'Flutter test with coverage' -Action {
    flutter test test --coverage --concurrency=1
  }

  Run-Step -Name 'Coverage guard' -Action {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/coverage_guard.ps1')
  }
} else {
  Run-Step -Name 'Flutter test' -Action {
    flutter test --concurrency=1
  }
}

Run-Step -Name 'Architecture check' -Action {
  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'check_architecture.ps1')
}

Run-Step -Name 'Release guard' -Action {
  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/release_guard.ps1')
}

if ($IncludeAndroidRuntime) {
  Run-Step -Name 'Android runtime gate' -Action {
    $runtimeGatePath = Join-Path $root 'scripts/strict_android_runtime_gate.ps1'
    $args = @(
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      $runtimeGatePath,
      '-PackageName',
      $AndroidPackageName
    )

    if ($RequireAndroidDevice) {
      $args += '-RequireDevice'
    }

    powershell @args
  }
}

Write-Host ''
Write-Host 'STRICT GATE PASSED' -ForegroundColor Green
