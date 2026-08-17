param(
  [switch]$IncludeAndroidRuntime,
  [switch]$IncludeCoverage,
  [switch]$IncludeIntegrationTest,
  [switch]$IncludeDependencyAudit,
  [switch]$RequireAndroidDevice,
  [string]$AndroidPackageName = 'com.ghostheart5.chronospark'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$powerShellCommand = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }

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

Run-Step -Name 'Format verification' -Action {
  dart format --output=none --set-exit-if-changed lib test integration_test
}

Run-Step -Name 'Security secret guard' -Action {
  & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/security_secret_guard.ps1')
}

Run-Step -Name 'Secret content guard' -Action {
  & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/secret_content_guard.ps1')
}

Run-Step -Name 'Flutter analyze' -Action {
  flutter analyze --fatal-infos
}

Run-Step -Name 'Maestro flow contract validation' -Action {
  dart run tool/validate_maestro_flows.dart
}

Run-Step -Name 'Supabase Edge Function gate' -Action {
  & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/edge_function_gate.ps1') -RunTests
}

if ($IncludeCoverage) {
  Run-Step -Name 'Flutter test with coverage' -Action {
    flutter test test --coverage --concurrency=1
  }

  Run-Step -Name 'Coverage guard' -Action {
    & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/coverage_guard.ps1') -Mode ratchet
  }
} else {
  Run-Step -Name 'Flutter test' -Action {
    flutter test --concurrency=1
  }
}

if ($IncludeIntegrationTest) {
  Run-Step -Name 'Flutter integration tests (host/device prerequisites required)' -Action {
    flutter test integration_test --concurrency=1
  }
}

if ($IncludeDependencyAudit) {
  Run-Step -Name 'Dependency audit report' -Action {
    & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/dependency_audit.ps1')
  }
}

Run-Step -Name 'Architecture check' -Action {
  & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'check_architecture.ps1')
}

Run-Step -Name 'Release guard' -Action {
  & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/release_guard.ps1')
}

Run-Step -Name 'Version consistency guard' -Action {
  & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/version_consistency_guard.ps1')
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

    & $powerShellCommand @args
  }
}

Write-Host ''
Write-Host 'STRICT GATE PASSED' -ForegroundColor Green
