$ErrorActionPreference = 'Stop'

$guard = Join-Path $PSScriptRoot 'coverage_guard.ps1'
$failures = New-Object System.Collections.Generic.List[string]
$powerShellCommand = if (Get-Command pwsh -ErrorAction SilentlyContinue) {
  'pwsh'
} elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
  'powershell'
} else {
  throw 'PowerShell is required to run the coverage guard contract.'
}
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "chronospark-coverage-guard-$([guid]::NewGuid().ToString('N'))"

$criticalSources = @(
  'lib/data/services/auth_service.dart',
  'lib/data/services/backup_service.dart',
  'lib/data/repositories/google_play_paywall_repository.dart',
  'lib/data/services/sync_service.dart',
  'lib/core/debug/runtime_diagnostics.dart'
)
$criticalTests = @(
  'test/data/services/auth_service_delete_account_test.dart',
  'test/data/services/backup_service_test.dart',
  'test/data/repositories/google_play_paywall_repository_test.dart',
  'test/data/services/sync_service_test.dart',
  'test/core/debug/runtime_diagnostics_test.dart'
)

function Set-FixtureFile {
  param(
    [string]$CaseRoot,
    [string]$RelativePath,
    [string]$Content = ''
  )

  $path = Join-Path $CaseRoot $RelativePath
  New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
  Set-Content -LiteralPath $path -Value $Content -NoNewline
}

function Get-FixtureExclusionsDigest {
  param([string]$CaseRoot, [string[]]$Paths)

  $builder = New-Object System.Text.StringBuilder
  foreach ($path in @($Paths | Sort-Object)) {
    $normalizedContent = [System.IO.File]::ReadAllText((Join-Path $CaseRoot $path)).
      Replace("`r`n", "`n").Replace("`r", "`n")
    [void]$builder.Append($path.Replace('\', '/'))
    [void]$builder.Append("`n")
    [void]$builder.Append($normalizedContent)
    [void]$builder.Append("`n--END-OF-EXCLUSION--`n")
  }
  $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($builder.ToString())
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha256.Dispose()
  }
}

function New-CoverageFixture {
  param(
    [string]$Name,
    [int]$AppIntegrationCount = 5,
    [int]$HostIntegrationCount = 0,
    [switch]$AddOmittedExecutable,
    [switch]$ExcludeOmittedDeclaration
  )

  $caseRoot = Join-Path $fixtureRoot $Name
  New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null

  $coveredSources = @('lib/covered.dart') + $criticalSources
  foreach ($source in $coveredSources) {
    Set-FixtureFile -CaseRoot $caseRoot -RelativePath $source -Content 'void covered() {}'
  }
  foreach ($test in $criticalTests) {
    Set-FixtureFile -CaseRoot $caseRoot -RelativePath $test -Content '// required companion contract'
  }
  for ($index = 1; $index -le $AppIntegrationCount; $index++) {
    Set-FixtureFile `
      -CaseRoot $caseRoot `
      -RelativePath "integration_test/app_flow_$($index)_test.dart" `
      -Content "test('app flow $index', () {});"
  }
  for ($index = 1; $index -le $HostIntegrationCount; $index++) {
    Set-FixtureFile `
      -CaseRoot $caseRoot `
      -RelativePath "test/integration/host_flow_$($index)_test.dart" `
      -Content '// host integration fixture'
  }

  $exclusionPaths = @()
  if ($AddOmittedExecutable) {
    Set-FixtureFile `
      -CaseRoot $caseRoot `
      -RelativePath 'lib/omitted_executable.dart' `
      -Content 'int omittedExecutable() => 42;'
  }
  if ($ExcludeOmittedDeclaration) {
    Set-FixtureFile `
      -CaseRoot $caseRoot `
      -RelativePath 'lib/declaration_only.dart' `
      -Content 'abstract interface class DeclarationOnly { void run(); }'
    $exclusionPaths += 'lib/declaration_only.dart'
  }
  $exclusions = @('# reviewed fixture exclusions') + $exclusionPaths
  Set-FixtureFile `
    -CaseRoot $caseRoot `
    -RelativePath 'scripts/coverage_exclusions.txt' `
    -Content ($exclusions -join "`n")
  Set-FixtureFile `
    -CaseRoot $caseRoot `
    -RelativePath 'scripts/coverage_exclusions.lock.sha256' `
    -Content (Get-FixtureExclusionsDigest -CaseRoot $caseRoot -Paths $exclusionPaths)

  $lcov = New-Object System.Collections.Generic.List[string]
  foreach ($source in $coveredSources) {
    $lcov.Add("SF:$source")
    $lcov.Add('DA:1,1')
    $lcov.Add('LF:1')
    $lcov.Add('LH:1')
    $lcov.Add('end_of_record')
  }
  Set-FixtureFile `
    -CaseRoot $caseRoot `
    -RelativePath 'coverage/lcov.info' `
    -Content ($lcov -join "`n")

  return $caseRoot
}

function Invoke-ContractCase {
  param(
    [string]$Name,
    [string]$CaseRoot,
    [int]$ExpectedExitCode,
    [string[]]$ExpectedMessages
  )

  $arguments = @('-NoProfile')
  if ($env:OS -eq 'Windows_NT') {
    $arguments += @('-ExecutionPolicy', 'Bypass')
  }
  $arguments += @(
    '-File', $guard,
    '-RepositoryRoot', $CaseRoot,
    '-Mode', 'target',
    '-MinOverallPercent', '0'
  )

  $output = & $powerShellCommand @arguments 2>&1
  $exitCode = $LASTEXITCODE
  $outputText = $output -join "`n"
  if ($exitCode -ne $ExpectedExitCode) {
    $failures.Add(
      "$Name expected exit code $ExpectedExitCode but received $exitCode.`n$outputText"
    )
  }
  foreach ($expectedMessage in $ExpectedMessages) {
    if ($outputText -notmatch [regex]::Escape($expectedMessage)) {
      $failures.Add("$Name did not emit expected message '$expectedMessage'.`n$outputText")
    }
  }
}

try {
  $completeInventory = New-CoverageFixture `
    -Name 'complete-inventory' `
    -AppIntegrationCount 5 `
    -HostIntegrationCount 9
  Invoke-ContractCase `
    -Name 'Complete production inventory passes and reports integration roots separately' `
    -CaseRoot $completeInventory `
    -ExpectedExitCode 0 `
    -ExpectedMessages @(
      'Production Dart inventory: 6 LCOV-tracked, 0 counted at zero, 0 reviewed declaration-only exclusions',
      'App-root integration flow count: 5 across 5 file(s)',
      'Host integration test count: 9',
      'Coverage guard passed.'
    )

  $omittedExecutable = New-CoverageFixture `
    -Name 'omitted-executable' `
    -AddOmittedExecutable
  Invoke-ContractCase `
    -Name 'Executable production source omitted from LCOV counts as zero' `
    -CaseRoot $omittedExecutable `
    -ExpectedExitCode 0 `
    -ExpectedMessages @(
      'Production Dart inventory: 6 LCOV-tracked, 1 counted at zero, 0 reviewed declaration-only exclusions',
      '1 production source file(s) were absent from LCOV and conservatively counted as zero coverage.'
    )

  $reviewedDeclaration = New-CoverageFixture `
    -Name 'reviewed-declaration' `
    -ExcludeOmittedDeclaration
  Invoke-ContractCase `
    -Name 'Explicit reviewed declaration-only exclusion may be absent from LCOV' `
    -CaseRoot $reviewedDeclaration `
    -ExpectedExitCode 0 `
    -ExpectedMessages @(
      'Production Dart inventory: 6 LCOV-tracked, 0 counted at zero, 1 reviewed declaration-only exclusions',
      'Coverage guard passed.'
    )

  $changedDeclaration = New-CoverageFixture `
    -Name 'changed-declaration' `
    -ExcludeOmittedDeclaration
  Set-FixtureFile `
    -CaseRoot $changedDeclaration `
    -RelativePath 'lib/declaration_only.dart' `
    -Content 'abstract interface class DeclarationOnly { void run(); } int executable() => 42;'
  Invoke-ContractCase `
    -Name 'Changed excluded source requires explicit re-review' `
    -CaseRoot $changedDeclaration `
    -ExpectedExitCode 1 `
    -ExpectedMessages @('Reviewed coverage exclusion content changed.')

  $hostOnly = New-CoverageFixture `
    -Name 'host-only-integration' `
    -AppIntegrationCount 0 `
    -HostIntegrationCount 5
  Invoke-ContractCase `
    -Name 'Host integration tests cannot satisfy app-root minimum' `
    -CaseRoot $hostOnly `
    -ExpectedExitCode 1 `
    -ExpectedMessages @(
      'App-root integration flows found: 0 across 0 file(s). Require at least 5 declared critical flows under integration_test/; host tests do not satisfy this minimum.',
      'Host integration test count: 5'
    )
} finally {
  $resolvedFixture = [System.IO.Path]::GetFullPath($fixtureRoot)
  $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  if ($resolvedFixture.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force -ErrorAction SilentlyContinue
  }
}

if ($failures.Count -gt 0) {
  Write-Host 'Coverage guard contract failed:' -ForegroundColor Red
  $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'Coverage guard contract passed.' -ForegroundColor Green
