param(
  [string]$CoverageFile = 'coverage/lcov.info',
  [double]$MinOverallPercent = 37.0,
  [ValidateSet('target', 'ratchet')]
  [string]$Mode = 'target',
  [string]$RepositoryRoot = '',
  [string]$CoverageExclusionsFile = 'scripts/coverage_exclusions.txt',
  [string]$CoverageExclusionsLockFile = 'scripts/coverage_exclusions.lock.sha256'
)

$ErrorActionPreference = 'Stop'

$root = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  Split-Path -Parent $PSScriptRoot
} else {
  [System.IO.Path]::GetFullPath($RepositoryRoot)
}
Set-Location $root

$criticalThresholds = @{
  'lib/data/services/auth_service.dart' = 90.0
  'lib/data/services/backup_service.dart' = 95.0
  'lib/data/repositories/google_play_paywall_repository.dart' = 88.0
  'lib/data/services/sync_service.dart' = 95.0
  'lib/core/debug/runtime_diagnostics.dart' = 94.0
}

# Target mode is the release-quality destination. Ratchet mode is the
# enforceable CI floor captured by the 2026-08-17 full-suite baseline. Keeping
# these separate prevents regression without pretending the existing
# repository already satisfies its declared target architecture.
$ratchetCriticalThresholds = @{
  'lib/data/services/auth_service.dart' = 80.5
  'lib/data/services/backup_service.dart' = 93.5
  'lib/data/repositories/google_play_paywall_repository.dart' = 76.0
  'lib/data/services/sync_service.dart' = 61.5
  'lib/core/debug/runtime_diagnostics.dart' = 89.5
}

$ratchetLayerThresholds = @{
  'domain/usecases' = 60.0
  'domain/policies' = 99.0
  'domain/value_objects' = 63.0
  'data/repositories' = 52.0
  'data/storage' = 51.0
  'state/controllers/providers' = 41.5
  'engine/si' = 64.5
  # The inventory-complete denominator counts omitted production UI files at
  # zero. The prior 62.5 floor came from LCOV-present files only and is not
  # comparable; retain the declared 50% release floor until exact-head CI sets
  # a higher inventory-complete ratchet.
  'features/ui' = 50.0
}

$effectiveOverallMinimum = if ($Mode -eq 'ratchet') {
  [math]::Max($MinOverallPercent, 52.0)
} else {
  $MinOverallPercent
}

$layerThresholds = @(
  @{
    Name = 'domain/usecases'
    Prefixes = @('lib/domain/usecases/')
    Min = 85.0
    Target = '85-95%'
  },
  @{
    Name = 'domain/policies'
    Prefixes = @('lib/domain/policies/')
    Min = 90.0
    Target = '90%+'
  },
  @{
    Name = 'domain/value_objects'
    Prefixes = @('lib/domain/value_objects/')
    Min = 90.0
    Target = '90%+'
  },
  @{
    Name = 'data/repositories'
    Prefixes = @('lib/data/repositories/')
    Min = 75.0
    Target = '75-85%'
  },
  @{
    Name = 'data/storage'
    Prefixes = @('lib/data/storage/')
    Min = 80.0
    Target = '80-90%'
  },
  @{
    Name = 'state/controllers/providers'
    Prefixes = @('lib/state/controllers/', 'lib/state/providers/')
    Min = 70.0
    Target = '70-85%'
  },
  @{
    Name = 'engine/si'
    Prefixes = @('lib/engine/si/')
    Min = 70.0
    Target = '70-85% meaningful'
  },
  @{
    Name = 'features/ui'
    Prefixes = @('lib/features/')
    IncludeRegex = '/(ui|widgets|screens?)/'
    Min = 50.0
    Target = '50-70% concentrated'
  }
)

$integrationFlowMinimum = 5
$integrationFlowTargetMax = 8

$criticalTestFiles = @{
  'lib/data/services/auth_service.dart' = @(
    'test/data/services/auth_service_delete_account_test.dart'
  )
  'lib/data/services/backup_service.dart' = @(
    'test/data/services/backup_service_test.dart'
  )
  'lib/data/repositories/google_play_paywall_repository.dart' = @(
    'test/data/repositories/google_play_paywall_repository_test.dart'
  )
  'lib/data/services/sync_service.dart' = @(
    'test/data/services/sync_service_test.dart'
  )
  'lib/core/debug/runtime_diagnostics.dart' = @(
    'test/core/debug/runtime_diagnostics_test.dart'
  )
}

function Convert-ToRepositoryPath {
  param([string]$Path)

  $normalized = $Path.Replace('\', '/').Trim()
  while ($normalized.StartsWith('./')) {
    $normalized = $normalized.Substring(2)
  }

  $normalizedRoot = $root.Replace('\', '/').TrimEnd('/')
  if ($normalized.StartsWith("$normalizedRoot/", [System.StringComparison]::OrdinalIgnoreCase)) {
    return $normalized.Substring($normalizedRoot.Length + 1)
  }

  return $normalized
}

function Get-CoverageExclusionsDigest {
  param([string[]]$Paths)

  $builder = New-Object System.Text.StringBuilder
  foreach ($path in @($Paths | Sort-Object)) {
    $absolutePath = Join-Path $root $path
    $normalizedContent = [System.IO.File]::ReadAllText($absolutePath).
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

if (-not (Test-Path -LiteralPath $CoverageExclusionsFile -PathType Leaf)) {
  throw "Reviewed coverage exclusions file not found: $CoverageExclusionsFile"
}

$ignoredCoveragePaths = @(
  Get-Content -LiteralPath $CoverageExclusionsFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') } |
    ForEach-Object { Convert-ToRepositoryPath $_ }
)

$duplicateExclusions = @(
  $ignoredCoveragePaths |
    Group-Object |
    Where-Object { $_.Count -gt 1 } |
    ForEach-Object { $_.Name }
)
if ($duplicateExclusions.Count -gt 0) {
  throw "Reviewed coverage exclusions contain duplicate paths: $($duplicateExclusions -join ', ')"
}

foreach ($ignoredPath in $ignoredCoveragePaths) {
  if (-not $ignoredPath.StartsWith('lib/') -or -not $ignoredPath.EndsWith('.dart')) {
    throw "Reviewed coverage exclusion must be an explicit lib/*.dart path: $ignoredPath"
  }
  if (-not (Test-Path -LiteralPath (Join-Path $root $ignoredPath) -PathType Leaf)) {
    throw "Reviewed coverage exclusion does not exist: $ignoredPath"
  }
}

if (-not (Test-Path -LiteralPath $CoverageExclusionsLockFile -PathType Leaf)) {
  throw "Reviewed coverage exclusions lock not found: $CoverageExclusionsLockFile"
}
$expectedExclusionsDigest = (Get-Content -LiteralPath $CoverageExclusionsLockFile -Raw).Trim().ToLowerInvariant()
if ($expectedExclusionsDigest -notmatch '^[a-f0-9]{64}$') {
  throw "Reviewed coverage exclusions lock must contain one SHA-256 digest: $CoverageExclusionsLockFile"
}
$actualExclusionsDigest = Get-CoverageExclusionsDigest -Paths $ignoredCoveragePaths
if ($actualExclusionsDigest -cne $expectedExclusionsDigest) {
  throw 'Reviewed coverage exclusion content changed. Re-review every excluded path as declaration-only, then update the lock digest explicitly.'
}

$allProductionSourcePaths = @(
  Get-ChildItem -LiteralPath (Join-Path $root 'lib') -Filter '*.dart' -Recurse -File |
    ForEach-Object {
      $_.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    }
)
$productionSourcePaths = @(
  $allProductionSourcePaths | Where-Object { $ignoredCoveragePaths -notcontains $_ }
)

if (-not (Test-Path $CoverageFile)) {
  Write-Host "Coverage file not found: $CoverageFile" -ForegroundColor Red
  exit 1
}

$records = New-Object System.Collections.Generic.List[object]
$current = $null
$lf = 0
$lh = 0

function Get-SumOrZero {
  param([object]$Value)
  if ($null -eq $Value -or $Value -eq '') {
    return 0
  }
  return [int]$Value
}

Get-Content $CoverageFile | ForEach-Object {
  if ($_ -like 'SF:*') {
    $current = Convert-ToRepositoryPath $_.Substring(3)
  } elseif ($_ -like 'LF:*') {
    $lf = [int]$_.Substring(3)
  } elseif ($_ -like 'LH:*') {
    $lh = [int]$_.Substring(3)
  } elseif ($_ -eq 'end_of_record' -and $null -ne $current) {
    $coverage = if ($lf -gt 0) { [math]::Round(($lh / $lf) * 100, 1) } else { 0.0 }
    $records.Add([pscustomobject]@{
      File = $current
      LF = $lf
      LH = $lh
      Coverage = $coverage
    }) | Out-Null
    $current = $null
    $lf = 0
    $lh = 0
  }
}

$activeRecords = @(
  $records | Where-Object { $productionSourcePaths -contains $_.File }
)
$trackedProductionPaths = @($activeRecords | ForEach-Object { $_.File } | Select-Object -Unique)
$missingCoveragePaths = @(
  $productionSourcePaths | Where-Object { $trackedProductionPaths -notcontains $_ }
)
$missingCoverageRecords = @(
  foreach ($missingCoveragePath in $missingCoveragePaths) {
    $fullSourcePath = Join-Path $root $missingCoveragePath
    $conservativeLineCount = @(
      Get-Content -LiteralPath $fullSourcePath |
        Where-Object {
          $trimmed = $_.Trim()
          $trimmed -and
            -not $trimmed.StartsWith('//') -and
            -not $trimmed.StartsWith('///')
        }
    ).Count
    [pscustomobject]@{
      File = $missingCoveragePath
      LF = [math]::Max(1, $conservativeLineCount)
      LH = 0
      Coverage = 0.0
      SyntheticZero = $true
    }
  }
)
$activeRecords = @($activeRecords) + @($missingCoverageRecords)
$overallLf = Get-SumOrZero (($activeRecords | Measure-Object -Property LF -Sum).Sum)
$overallLh = Get-SumOrZero (($activeRecords | Measure-Object -Property LH -Sum).Sum)
$overallCoverage = if ($overallLf -gt 0) {
  [math]::Round(($overallLh / $overallLf) * 100, 1)
} else {
  0.0
}

$criticalRecords = foreach ($entry in $criticalThresholds.GetEnumerator()) {
  $activeRecords | Where-Object { $_.File -eq $entry.Key } | Select-Object -First 1
}
$criticalLf = Get-SumOrZero (($criticalRecords | Measure-Object -Property LF -Sum).Sum)
$criticalLh = Get-SumOrZero (($criticalRecords | Measure-Object -Property LH -Sum).Sum)
$criticalCoverage = if ($criticalLf -gt 0) {
  [math]::Round(($criticalLh / $criticalLf) * 100, 1)
} else {
  0.0
}

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
if ($missingCoveragePaths.Count -gt 0) {
  $warnings.Add(
    "$($missingCoveragePaths.Count) production source file(s) were absent from LCOV and conservatively counted as zero coverage."
  ) | Out-Null
}

$layerResults = New-Object System.Collections.Generic.List[object]

foreach ($layer in $layerThresholds) {
  $prefixes = @($layer.Prefixes)
  $includeRegex = if ($layer.ContainsKey('IncludeRegex')) { [string]$layer.IncludeRegex } else { $null }

  $layerSourcePaths = @(
    $productionSourcePaths | Where-Object {
      $file = $_
      $prefixMatched = $false
      foreach ($prefix in $prefixes) {
        if ($file.StartsWith($prefix)) {
          $prefixMatched = $true
          break
        }
      }
      if (-not $prefixMatched) {
        return $false
      }
      if ($null -ne $includeRegex -and $includeRegex.Length -gt 0) {
        return ($file -match $includeRegex)
      }
      return $true
    }
  )
  $layerSourceCount = $layerSourcePaths.Count

  $layerRecords = $activeRecords | Where-Object {
    $file = $_.File
    $prefixMatched = $false
    foreach ($prefix in $prefixes) {
      if ($file.StartsWith($prefix)) {
        $prefixMatched = $true
        break
      }
    }
    if (-not $prefixMatched) {
      return $false
    }
    if ($null -ne $includeRegex -and $includeRegex.Length -gt 0) {
      return ($file -match $includeRegex)
    }
    return $true
  }

  $layerLf = Get-SumOrZero (($layerRecords | Measure-Object -Property LF -Sum).Sum)
  $layerLh = Get-SumOrZero (($layerRecords | Measure-Object -Property LH -Sum).Sum)
  $layerCoverage = if ($layerLf -gt 0) {
    [math]::Round(($layerLh / $layerLf) * 100, 1)
  } else {
    0.0
  }

  $layerResults.Add([pscustomobject]@{
    Name = $layer.Name
    Coverage = $layerCoverage
    LF = $layerLf
    LH = $layerLh
    Min = [double]$layer.Min
    GateMin = if ($Mode -eq 'ratchet') {
      [double]$ratchetLayerThresholds[$layer.Name]
    } else {
      [double]$layer.Min
    }
    Target = $layer.Target
    SourceCount = $layerSourceCount
    TrackedFiles = ($layerRecords | Measure-Object).Count
  }) | Out-Null

  if ($layerSourceCount -gt 0 -and $layerLf -eq 0) {
    $failures.Add(
      "Layer $($layer.Name) has source files but no coverage records. Add tests that execute this layer."
    ) | Out-Null
    continue
  }

  $gateMinimum = if ($Mode -eq 'ratchet') {
    [double]$ratchetLayerThresholds[$layer.Name]
  } else {
    [double]$layer.Min
  }

  if ($layerLf -gt 0 -and [double]$layerCoverage -lt $gateMinimum) {
    $failures.Add(
      "Layer $($layer.Name) coverage is $layerCoverage% but the $Mode gate requires at least $gateMinimum% (target $($layer.Target))."
    ) | Out-Null
  } elseif ($Mode -eq 'ratchet' -and [double]$layerCoverage -lt [double]$layer.Min) {
    $warnings.Add(
      "Layer $($layer.Name) is above its ratchet floor but below the $($layer.Min)% target."
    ) | Out-Null
  }
}

$appIntegrationTestsPath = Join-Path $root 'integration_test'
$hostIntegrationTestsPath = Join-Path $root 'test/integration'
$appIntegrationFiles = if (Test-Path $appIntegrationTestsPath) {
  @(
    Get-ChildItem -Path $appIntegrationTestsPath -Filter '*_test.dart' -File -Recurse
  )
} else {
  @()
}
$appIntegrationFlowCount = if ($appIntegrationFiles.Count -gt 0) {
  Get-SumOrZero (
    $appIntegrationFiles |
      Select-String -Pattern '^\s*(?:test|testWidgets)\s*\(' |
      Measure-Object |
      Select-Object -ExpandProperty Count
  )
} else {
  0
}
$hostIntegrationTestCount = if (Test-Path $hostIntegrationTestsPath) {
  Get-SumOrZero (
    Get-ChildItem -Path $hostIntegrationTestsPath -Filter '*_test.dart' -File -Recurse |
      Measure-Object |
      Select-Object -ExpandProperty Count
  )
} else {
  0
}

if ($appIntegrationFlowCount -lt $integrationFlowMinimum) {
  $failures.Add(
    "App-root integration flows found: $appIntegrationFlowCount across $($appIntegrationFiles.Count) file(s). Require at least $integrationFlowMinimum declared critical flows under integration_test/; host tests do not satisfy this minimum."
  ) | Out-Null
}

if ($appIntegrationFlowCount -gt $integrationFlowTargetMax) {
  $warnings.Add(
    "App-root integration tests found: $appIntegrationFlowCount. Keep 5-8 critical flows as required gates and move extra coverage to unit/widget tests when practical."
  ) | Out-Null
}

if ($overallCoverage -lt $effectiveOverallMinimum) {
  $failures.Add(
    "Overall coverage $overallCoverage% is below the $Mode gate minimum $effectiveOverallMinimum%."
  ) | Out-Null
}

foreach ($entry in $criticalThresholds.GetEnumerator()) {
  $path = $entry.Key
  $target = [double]$entry.Value
  $required = if ($Mode -eq 'ratchet') {
    [double]$ratchetCriticalThresholds[$path]
  } else {
    $target
  }
  $record = $activeRecords | Where-Object { $_.File -eq $path } | Select-Object -First 1

  if (-not $record) {
    $failures.Add("Critical coverage target missing from report: $path") | Out-Null
    continue
  }

  if ([double]$record.Coverage -lt $required) {
    $failures.Add(
      "Coverage for $path is $($record.Coverage)% but requires at least $required%."
    ) | Out-Null
  } elseif ($Mode -eq 'ratchet' -and [double]$record.Coverage -lt $target) {
    $warnings.Add(
      "Coverage for $path is above its ratchet floor but below the $target% target."
    ) | Out-Null
  }
}

foreach ($entry in $criticalTestFiles.GetEnumerator()) {
  $sourcePath = $entry.Key
  foreach ($testPath in $entry.Value) {
    if (-not (Test-Path (Join-Path $root $testPath))) {
      $failures.Add(
        "Critical source file $sourcePath is missing required test file $testPath."
      ) | Out-Null
    }
  }
}

Write-Host ("Coverage gate mode: {0}" -f $Mode)
Write-Host ("Overall coverage: {0}% (gate {1}%)" -f $overallCoverage, $effectiveOverallMinimum)
Write-Host ("Production Dart inventory: {0} LCOV-tracked, {1} counted at zero, {2} reviewed declaration-only exclusions" -f $trackedProductionPaths.Count, $missingCoveragePaths.Count, $ignoredCoveragePaths.Count)
Write-Host ("Critical-only coverage: {0}%" -f $criticalCoverage)
Write-Host ("App-root integration flow count: {0} across {1} file(s)" -f $appIntegrationFlowCount, $appIntegrationFiles.Count)
Write-Host ("Host integration test count: {0} (reported separately; does not satisfy the app-root minimum)" -f $hostIntegrationTestCount)
Write-Host 'Critical coverage targets:'
foreach ($entry in $criticalThresholds.GetEnumerator()) {
  $path = $entry.Key
  $record = $activeRecords | Where-Object { $_.File -eq $path } | Select-Object -First 1
  if ($record) {
    Write-Host (" - {0}: {1}%" -f $path, $record.Coverage)
  } else {
    Write-Host (" - {0}: missing" -f $path)
  }
}

Write-Host 'Layer coverage targets:'
foreach ($layer in $layerResults) {
  Write-Host (
    " - {0}: {1}% ({2}/{3}), gate {4}% target {5}" -f
      $layer.Name,
      $layer.Coverage,
      $layer.LH,
      $layer.LF,
      $layer.GateMin,
      $layer.Target
  )
}

if ($warnings.Count -gt 0) {
  Write-Host ''
  Write-Host 'Coverage guard warnings:' -ForegroundColor Yellow
  foreach ($warning in $warnings) {
    Write-Host " - $warning" -ForegroundColor Yellow
  }
}

if ($failures.Count -gt 0) {
  Write-Host ''
  Write-Host 'Coverage guard failed:' -ForegroundColor Red
  foreach ($failure in $failures) {
    Write-Host " - $failure" -ForegroundColor Red
  }
  exit 1
}

Write-Host 'Coverage guard passed.' -ForegroundColor Green
exit 0
