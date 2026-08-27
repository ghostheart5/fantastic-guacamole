param(
  [switch]$IncludeAndroidRuntime,
  [switch]$IncludeCoverage,
  [switch]$IncludeIntegrationTest,
  [switch]$IncludeDependencyAudit,
  [switch]$RequireAndroidDevice,
  [switch]$AllowDirtyTree,
  [string]$EvidenceDirectory,
  [string]$AndroidPackageName = 'com.ghostheart5.chronospark'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$powerShellCommand = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
$stageResults = [System.Collections.Generic.List[object]]::new()
$sourceCommit = (& git rev-parse HEAD).Trim()
$sourceBranch = (& git branch --show-current).Trim()
$dirtyEntries = @(& git status --porcelain=v1)

if (-not $AllowDirtyTree -and $dirtyEntries.Count -gt 0) {
  throw "Strict gate requires a clean source snapshot. Found $($dirtyEntries.Count) dirty path(s). Commit or preserve them first."
}

function Run-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host ""
  Write-Host "==> $Name"
  try {
    & $Action
    $stepExitCode = $LASTEXITCODE
    if ($stepExitCode -ne 0) {
      throw "$Name failed with exit code $stepExitCode"
    }
    $stageResults.Add([pscustomobject]@{ Stage = $Name; Result = 'PASS' }) | Out-Null
  }
  catch {
    $stageResults.Add([pscustomobject]@{ Stage = $Name; Result = 'FAIL' }) | Out-Null
    throw
  }
}

function Skip-Step {
  param([string]$Name, [string]$Reason)
  Write-Host "==> $Name [SKIPPED] $Reason" -ForegroundColor Yellow
  $stageResults.Add(
    [pscustomobject]@{ Stage = $Name; Result = "SKIPPED: $Reason" }
  ) | Out-Null
}

Write-Host 'Running strict ChronoSpark gate...'
Write-Host "Source commit: $sourceCommit"
Write-Host "Source branch: $sourceBranch"
Write-Host "Dirty checkout: $($dirtyEntries.Count -gt 0) ($($dirtyEntries.Count) entries)"

Run-Step -Name 'Format verification' -Action {
  dart format --output=none --set-exit-if-changed lib test integration_test
}

Run-Step -Name 'Security secret guard' -Action {
  & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/security_secret_guard.ps1')
}

Run-Step -Name 'Secret content guard' -Action {
  & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/secret_content_guard.ps1')
}

Run-Step -Name 'GitHub workflow policy validation' -Action {
  dart run tool/validate_github_workflows.dart
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
  Skip-Step -Name 'Coverage guard' -Reason '-IncludeCoverage was not selected.'
}

if ($IncludeIntegrationTest) {
  Run-Step -Name 'Flutter integration tests (host/device prerequisites required)' -Action {
    flutter test integration_test --concurrency=1
  }
} else {
  Skip-Step -Name 'Flutter integration tests' -Reason '-IncludeIntegrationTest was not selected.'
}

if ($IncludeDependencyAudit) {
  Run-Step -Name 'Dependency audit report' -Action {
    & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/dependency_audit.ps1')
  }
} else {
  Skip-Step -Name 'Dependency audit report' -Reason '-IncludeDependencyAudit was not selected.'
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
} else {
  Skip-Step -Name 'Android runtime gate' -Reason '-IncludeAndroidRuntime was not selected.'
}

Write-Host ''
$stageResults | Format-Table -AutoSize | Out-Host

if (-not [string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
  New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
  [ordered]@{
    schemaVersion = 1
    commit = $sourceCommit
    branch = $sourceBranch
    dirty = ($dirtyEntries.Count -gt 0)
    dirtyEntryCount = $dirtyEntries.Count
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    stages = @($stageResults)
  } | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'strict-gate-manifest.json') -Encoding utf8
}

$skippedCount = @($stageResults | Where-Object { $_.Result -like 'SKIPPED:*' }).Count
if ($skippedCount -gt 0) {
  Write-Host "STRICT GATE REQUIRED STAGES PASSED; $skippedCount OPTIONAL STAGE(S) SKIPPED" -ForegroundColor Yellow
} else {
  Write-Host 'STRICT GATE PASSED — ALL SELECTED STAGES EXECUTED' -ForegroundColor Green
}
