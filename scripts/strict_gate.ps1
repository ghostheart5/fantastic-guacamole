param(
  [switch]$IncludeAndroidRuntime,
  [switch]$IncludeCoverage,
  [switch]$IncludeIntegrationTest,
  [switch]$IncludeDependencyAudit,
  [switch]$RequireAndroidDevice,
  [switch]$AllowUnselectedStages,
  [switch]$AllowDirtyTree,
  [string]$EvidenceDirectory,
  [string]$AndroidPackageName = 'com.ghostheart5.chronospark',
  [string]$AndroidDeviceSerial
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$powerShellCommand = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
$stageResults = [System.Collections.Generic.List[object]]::new()
$sourceCommit = (& git rev-parse HEAD).Trim()
$sourceBranch = (& git branch --show-current).Trim()
$dirtyEntries = @(& git status --porcelain=v1)
$runId = (Get-Date -Format 'yyyyMMdd-HHmmssfff') + "-$PID"
$gateEvidenceRoot = if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
  Join-Path $root "test-results/strict-gate-$runId"
} else {
  [System.IO.Path]::GetFullPath($EvidenceDirectory)
}
$flutterEvidenceRoot = Join-Path $gateEvidenceRoot 'flutter-tests'
$androidRuntimeEvidencePath = Join-Path $gateEvidenceRoot 'android-runtime-launch.json'

function Write-GateManifest {
  param(
    [string]$OverallResult,
    [int]$ExitCode
  )

  New-Item -ItemType Directory -Force -Path $gateEvidenceRoot | Out-Null
  [ordered]@{
    schemaVersion = 1
    commit = $sourceCommit
    branch = $sourceBranch
    dirty = ($dirtyEntries.Count -gt 0)
    dirtyEntryCount = $dirtyEntries.Count
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    overallResult = $OverallResult
    exitCode = $ExitCode
    allowUnselectedStages = [bool]$AllowUnselectedStages
    flutterEvidenceDirectory = $flutterEvidenceRoot
    androidRuntimeEvidence = $androidRuntimeEvidencePath
    stages = @($stageResults)
  } | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath (Join-Path $gateEvidenceRoot 'strict-gate-manifest.json') -Encoding utf8
}

function Run-Step {
  param(
    [string]$Name,
    [scriptblock]$Action,
    [int[]]$PartialExitCodes = @()
  )

  Write-Host ""
  Write-Host "==> $Name"
  try {
    & $Action
    $stepExitCode = $LASTEXITCODE
    if ($PartialExitCodes -contains $stepExitCode) {
      $stageResults.Add(
        [pscustomobject]@{ Stage = $Name; Result = "PARTIAL: child exit code $stepExitCode (not run)" }
      ) | Out-Null
      return
    }
    if ($stepExitCode -ne 0) {
      throw "$Name failed with exit code $stepExitCode"
    }
    $stageResults.Add([pscustomobject]@{ Stage = $Name; Result = 'PASS' }) | Out-Null
  }
  catch {
    $stageResults.Add([pscustomobject]@{ Stage = $Name; Result = 'FAIL' }) | Out-Null
    Write-GateManifest -OverallResult 'FAIL' -ExitCode 1
    throw
  }
}

function Invoke-BoundedFlutterTests {
  param(
    [string]$Label,
    [int]$TimeoutSeconds,
    [string[]]$TestArguments
  )

  New-Item -ItemType Directory -Force -Path $flutterEvidenceRoot | Out-Null
  $reportPath = Join-Path $flutterEvidenceRoot "$Label.report.jsonl"
  $manifestPath = Join-Path $flutterEvidenceRoot "$Label.manifest.json"
  dart run tool/run_flutter_tests.dart `
    --report $reportPath `
    --manifest $manifestPath `
    --timeout-seconds $TimeoutSeconds `
    --allowed-skips 0 `
    -- @TestArguments
}

function Skip-Step {
  param([string]$Name, [string]$Reason)
  Write-Host "==> $Name [SKIPPED] $Reason" -ForegroundColor Yellow
  $stageResults.Add(
    [pscustomobject]@{ Stage = $Name; Result = "SKIPPED: $Reason" }
  ) | Out-Null
}

if (-not $AllowDirtyTree -and $dirtyEntries.Count -gt 0) {
  $stageResults.Add([pscustomobject]@{ Stage = 'Source snapshot'; Result = 'FAIL' }) | Out-Null
  Write-GateManifest -OverallResult 'FAIL' -ExitCode 1
  throw "Strict gate requires a clean source snapshot. Found $($dirtyEntries.Count) dirty path(s). Commit or preserve them first."
}

Write-Host 'Running strict ChronoSpark gate...'
Write-Host "Source commit: $sourceCommit"
Write-Host "Source branch: $sourceBranch"
Write-Host "Dirty checkout: $($dirtyEntries.Count -gt 0) ($($dirtyEntries.Count) entries)"

Run-Step -Name 'Format verification' -Action {
  dart format --output=none --set-exit-if-changed lib test integration_test tool scripts
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
    Invoke-BoundedFlutterTests `
      -Label 'host-coverage' `
      -TimeoutSeconds 3600 `
      -TestArguments @('test', '--coverage', '--concurrency=1')
  }

  Run-Step -Name 'Coverage guard' -Action {
    & $powerShellCommand -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/coverage_guard.ps1') -Mode ratchet
  }
} else {
  Run-Step -Name 'Flutter test' -Action {
    Invoke-BoundedFlutterTests `
      -Label 'host' `
      -TimeoutSeconds 3600 `
      -TestArguments @('--concurrency=1')
  }
  Skip-Step -Name 'Coverage guard' -Reason '-IncludeCoverage was not selected.'
}

if ($IncludeIntegrationTest) {
  Run-Step -Name 'Flutter integration tests (host/device prerequisites required)' -Action {
    Invoke-BoundedFlutterTests `
      -Label 'integration' `
      -TimeoutSeconds 3600 `
      -TestArguments @('integration_test', '--concurrency=1')
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
  Run-Step -Name 'Android runtime gate' -PartialExitCodes @(2) -Action {
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

    if (-not [string]::IsNullOrWhiteSpace($AndroidDeviceSerial)) {
      $args += @('-DeviceSerial', $AndroidDeviceSerial)
    }
    $args += @('-LaunchEvidencePath', $androidRuntimeEvidencePath)

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

$skippedCount = @($stageResults | Where-Object { $_.Result -like 'SKIPPED:*' }).Count
$partialStageCount = @($stageResults | Where-Object { $_.Result -like 'PARTIAL:*' }).Count
$overallResult = if (($skippedCount + $partialStageCount) -gt 0) { 'PARTIAL' } else { 'COMPLETE' }
$overallExitCode = if ($overallResult -eq 'COMPLETE') {
  0
} elseif ($partialStageCount -eq 0 -and $AllowUnselectedStages) {
  0
} else {
  2
}
Write-GateManifest -OverallResult $overallResult -ExitCode $overallExitCode

if ($overallResult -eq 'PARTIAL') {
  if ($overallExitCode -eq 0) {
    Write-Host "STRICT GATE PARTIAL SOURCE CHECK - $skippedCount UNSELECTED STAGE(S); ACCEPTED ONLY FOR THIS NON-RELEASE INVOCATION" -ForegroundColor Yellow
    exit 0
  }
  Write-Host "STRICT GATE PARTIAL - $skippedCount REQUIRED STAGE(S) SKIPPED; $partialStageCount REQUESTED STAGE(S) NOT RUN" -ForegroundColor Yellow
  exit 2
}

Write-Host 'STRICT GATE COMPLETE - ALL REQUIRED STAGES EXECUTED AND PASSED' -ForegroundColor Green
exit 0
