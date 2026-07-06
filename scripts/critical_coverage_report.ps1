param(
  [string]$CoverageFile = 'coverage/lcov.info'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$criticalTargets = @(
  'lib/data/services/auth_service.dart',
  'lib/data/services/backup_service.dart',
  'lib/data/repositories/google_play_paywall_repository.dart',
  'lib/data/services/sync_service.dart',
  'lib/core/debug/runtime_diagnostics.dart'
)

if (-not (Test-Path $CoverageFile)) {
  Write-Host "Coverage file not found: $CoverageFile" -ForegroundColor Red
  exit 1
}

$currentFile = $null
$lineHits = @{}
$lf = 0
$lh = 0
$records = New-Object System.Collections.Generic.List[object]

Get-Content $CoverageFile | ForEach-Object {
  if ($_ -like 'SF:*') {
    $currentFile = $_.Substring(3).Replace('\', '/')
    $lineHits = @{}
    $lf = 0
    $lh = 0
  } elseif ($_ -like 'DA:*') {
    $parts = $_.Substring(3).Split(',')
    if ($parts.Length -eq 2) {
      $lineHits[[int]$parts[0]] = [int]$parts[1]
    }
  } elseif ($_ -like 'LF:*') {
    $lf = [int]$_.Substring(3)
  } elseif ($_ -like 'LH:*') {
    $lh = [int]$_.Substring(3)
  } elseif ($_ -eq 'end_of_record' -and $null -ne $currentFile) {
    if ($criticalTargets -contains $currentFile) {
      $records.Add([pscustomobject]@{
        File = $currentFile
        LF = $lf
        LH = $lh
        Coverage = if ($lf -gt 0) { [math]::Round(($lh / $lf) * 100, 1) } else { 0.0 }
        UncoveredLines = @($lineHits.GetEnumerator() | Where-Object { $_.Value -eq 0 } | Sort-Object Name | ForEach-Object { $_.Name })
      }) | Out-Null
    }
    $currentFile = $null
  }
}

if ($records.Count -eq 0) {
  Write-Host 'No critical coverage targets were found in the coverage report.' -ForegroundColor Yellow
  exit 1
}

$overallLf = ($records | Measure-Object -Property LF -Sum).Sum
$overallLh = ($records | Measure-Object -Property LH -Sum).Sum
$criticalCoverage = if ($overallLf -gt 0) {
  [math]::Round(($overallLh / $overallLf) * 100, 1)
} else {
  0.0
}

Write-Host ("Critical-only coverage: {0}%" -f $criticalCoverage)
Write-Host ''
Write-Host 'Critical coverage detail:'

foreach ($record in $records | Sort-Object File) {
  Write-Host ("- {0}: {1}% ({2}/{3})" -f $record.File, $record.Coverage, $record.LH, $record.LF)
  if ($record.UncoveredLines.Count -eq 0) {
    Write-Host '  uncovered lines: none'
    continue
  }

  $lineList = ($record.UncoveredLines | ForEach-Object { $_.ToString() }) -join ', '
  Write-Host ("  uncovered lines: {0}" -f $lineList)
}

exit 0
