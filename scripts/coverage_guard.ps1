param(
  [string]$CoverageFile = 'coverage/lcov.info',
  [double]$MinOverallPercent = 37.0
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$criticalThresholds = @{
  'lib/data/services/auth_service.dart' = 90.0
  'lib/data/services/backup_service.dart' = 95.0
  'lib/data/repositories/google_play_paywall_repository.dart' = 88.0
  'lib/data/services/sync_service.dart' = 95.0
  'lib/core/debug/runtime_diagnostics.dart' = 94.0
}

$layerThresholds = @(
  @{
    Name = 'domain/usecases'
    Paths = @('lib/domain/usecases')
    Prefixes = @('lib/domain/usecases/')
    Min = 85.0
    Target = '85-95%'
  },
  @{
    Name = 'domain/policies'
    Paths = @('lib/domain/policies')
    Prefixes = @('lib/domain/policies/')
    Min = 90.0
    Target = '90%+'
  },
  @{
    Name = 'domain/value_objects'
    Paths = @('lib/domain/value_objects')
    Prefixes = @('lib/domain/value_objects/')
    Min = 90.0
    Target = '90%+'
  },
  @{
    Name = 'data/repositories'
    Paths = @('lib/data/repositories')
    Prefixes = @('lib/data/repositories/')
    Min = 75.0
    Target = '75-85%'
  },
  @{
    Name = 'data/storage'
    Paths = @('lib/data/storage')
    Prefixes = @('lib/data/storage/')
    Min = 80.0
    Target = '80-90%'
  },
  @{
    Name = 'state/controllers/providers'
    Paths = @('lib/state/controllers', 'lib/state/providers')
    Prefixes = @('lib/state/controllers/', 'lib/state/providers/')
    Min = 70.0
    Target = '70-85%'
  },
  @{
    Name = 'engine/si'
    Paths = @('lib/engine/si')
    Prefixes = @('lib/engine/si/')
    Min = 70.0
    Target = '70-85% meaningful'
  },
  @{
    Name = 'features/ui'
    Paths = @('lib/features')
    Prefixes = @('lib/features/')
    IncludeRegex = '/(ui|widgets|screens?)/'
    Min = 50.0
    Target = '50-70% focused'
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

$ignoredCoveragePaths = @(
  'lib/state/controllers/focus_session_controller.dart'
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
    $current = $_.Substring(3).Replace('\', '/')
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

$activeRecords = $records | Where-Object { $ignoredCoveragePaths -notcontains $_.File }
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

$layerResults = New-Object System.Collections.Generic.List[object]

foreach ($layer in $layerThresholds) {
  $prefixes = @($layer.Prefixes)
  $paths = @($layer.Paths)
  $includeRegex = if ($layer.ContainsKey('IncludeRegex')) { [string]$layer.IncludeRegex } else { $null }

  $layerSourceCount = 0
  foreach ($relativePath in $paths) {
    $fullPath = Join-Path $root $relativePath
    if (Test-Path $fullPath) {
      $layerSourceCount += Get-SumOrZero ((Get-ChildItem -Path $fullPath -Filter '*.dart' -Recurse -File | Measure-Object).Count)
    }
  }

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

  if ($layerLf -gt 0 -and [double]$layerCoverage -lt [double]$layer.Min) {
    $failures.Add(
      "Layer $($layer.Name) coverage is $layerCoverage% but requires at least $($layer.Min)% (target $($layer.Target))."
    ) | Out-Null
  }
}

$integrationTestsPath = Join-Path $root 'integration_test'
$integrationFlowCount = if (Test-Path $integrationTestsPath) {
  (Get-ChildItem -Path $integrationTestsPath -Filter '*_test.dart' -File | Measure-Object).Count
} else {
  0
}

if ($integrationFlowCount -lt $integrationFlowMinimum) {
  $failures.Add(
    "Integration tests found: $integrationFlowCount. Require at least $integrationFlowMinimum critical flows."
  ) | Out-Null
}

if ($integrationFlowCount -gt $integrationFlowTargetMax) {
  $warnings.Add(
    "Integration tests found: $integrationFlowCount. Keep 5-8 critical flows as required gates and move extra coverage to unit/widget tests when practical."
  ) | Out-Null
}

if ($overallCoverage -lt $MinOverallPercent) {
  $failures.Add(
    "Overall coverage $overallCoverage% is below required minimum $MinOverallPercent%."
  ) | Out-Null
}

foreach ($entry in $criticalThresholds.GetEnumerator()) {
  $path = $entry.Key
  $required = [double]$entry.Value
  $record = $activeRecords | Where-Object { $_.File -eq $path } | Select-Object -First 1

  if (-not $record) {
    $failures.Add("Critical coverage target missing from report: $path") | Out-Null
    continue
  }

  if ([double]$record.Coverage -lt $required) {
    $failures.Add(
      "Coverage for $path is $($record.Coverage)% but requires at least $required%."
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

Write-Host ("Overall coverage: {0}%" -f $overallCoverage)
Write-Host ("Critical-only coverage: {0}%" -f $criticalCoverage)
Write-Host ("Integration flow count: {0}" -f $integrationFlowCount)
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
    " - {0}: {1}% ({2}/{3}), min {4}% target {5}" -f
      $layer.Name,
      $layer.Coverage,
      $layer.LH,
      $layer.LF,
      $layer.Min,
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
