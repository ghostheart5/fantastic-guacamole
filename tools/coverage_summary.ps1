$ErrorActionPreference = 'Stop'

$coverageDir = "coverage"
$lcov = Join-Path $coverageDir "lcov.info"
$summaryOut = Join-Path $coverageDir "coverage_summary.txt"
$featureCsvOut = Join-Path $coverageDir "coverage_by_feature.csv"
$fileCsvOut = Join-Path $coverageDir "coverage_by_file.csv"
$zeroCoverageOut = Join-Path $coverageDir "zero_coverage_files.txt"

if (!(Test-Path $coverageDir)) {
  New-Item -ItemType Directory -Path $coverageDir | Out-Null
}

if (!(Test-Path $lcov)) {
  Write-Host "coverage/lcov.info not found. Run flutter test --coverage first."
  exit 1
}

$fileStats = @{}
$featureStats = @{}

$currentFile = $null
$currentFound = 0
$currentHit = 0

function Resolve-FeatureKey([string] $pathValue) {
  $normalized = $pathValue.Replace('\', '/')
  if ($normalized.StartsWith('lib/tutorial/')) {
    return 'tutorial'
  }

  if ($normalized.StartsWith('lib/features/')) {
    $parts = $normalized.Split('/')
    if ($parts.Length -ge 3) {
      return $parts[2]
    }
  }

  if ($normalized.StartsWith('lib/auth/')) {
    return 'auth'
  }

  if ($normalized.StartsWith('lib/storage/')) {
    return 'storage'
  }

  if ($normalized.StartsWith('lib/nexus/')) {
    return 'nexus'
  }

  if ($normalized.StartsWith('lib/creator/')) {
    return 'creator'
  }

  if ($normalized.StartsWith('lib/timeline/')) {
    return 'timeline'
  }

  if ($normalized.StartsWith('lib/trajectory/') -or $normalized.StartsWith('lib/trajectory_engine/')) {
    return 'trajectory_engine'
  }

  if ($normalized.StartsWith('lib/si/') -or $normalized.StartsWith('lib/si_console/')) {
    return 'si_console'
  }

  if ($normalized.StartsWith('lib/')) {
    $parts = $normalized.Split('/')
    if ($parts.Length -ge 2) {
      return $parts[1]
    }
  }

  return 'other'
}

function Commit-CurrentRecord {
  if ([string]::IsNullOrWhiteSpace($currentFile)) {
    return
  }

  $safeFound = [Math]::Max(0, [int] $currentFound)
  $safeHit = [Math]::Max(0, [int] $currentHit)
  $safeHit = [Math]::Min($safeHit, $safeFound)

  $fileStats[$currentFile] = [PSCustomObject]@{
    File = $currentFile
    Found = $safeFound
    Hit = $safeHit
    Percent = if ($safeFound -eq 0) { 0 } else { [Math]::Round(($safeHit / $safeFound) * 100, 2) }
  }

  $featureKey = Resolve-FeatureKey -pathValue $currentFile
  if (-not $featureStats.ContainsKey($featureKey)) {
    $featureStats[$featureKey] = [PSCustomObject]@{
      Feature = $featureKey
      Path = if ($featureKey -eq 'other') { 'other' } elseif ($featureKey -match '^lib/') { $featureKey } elseif ($featureKey -eq 'tutorial') { 'lib/tutorial' } else { "lib/features/$featureKey" }
      Found = 0
      Hit = 0
    }
  }

  $featureStats[$featureKey].Found += $safeFound
  $featureStats[$featureKey].Hit += $safeHit
}

Get-Content $lcov | ForEach-Object {
  $line = $_.Trim()

  if ($line.StartsWith('SF:')) {
    Commit-CurrentRecord
    $currentFile = $line.Substring(3)
    $currentFound = 0
    $currentHit = 0
    return
  }

  if ($line.StartsWith('LF:')) {
    $value = 0
    [void][int]::TryParse($line.Substring(3), [ref] $value)
    $currentFound = $value
    return
  }

  if ($line.StartsWith('LH:')) {
    $value = 0
    [void][int]::TryParse($line.Substring(3), [ref] $value)
    $currentHit = $value
    return
  }

  if ($line -eq 'end_of_record') {
    Commit-CurrentRecord
    $currentFile = $null
    $currentFound = 0
    $currentHit = 0
  }
}

Commit-CurrentRecord

$fileRows = @($fileStats.Values)
$featureRows = @($featureStats.Values | ForEach-Object {
  [PSCustomObject]@{
    Feature = $_.Feature
    Path = $_.Path
    Found = [int] $_.Found
    Hit = [int] $_.Hit
    Percent = if ($_.Found -eq 0) { 0 } else { [Math]::Round(($_.Hit / $_.Found) * 100, 2) }
  }
})

$linesFound = ($fileRows | Measure-Object -Property Found -Sum).Sum
$linesHit = ($fileRows | Measure-Object -Property Hit -Sum).Sum
if ($null -eq $linesFound) { $linesFound = 0 }
if ($null -eq $linesHit) { $linesHit = 0 }

$totalPercent = if ($linesFound -eq 0) { 0 } else { [Math]::Round(($linesHit / $linesFound) * 100, 2) }

$sortedLowFiles = @($fileRows | Sort-Object Percent, Found, File | Select-Object -First 20)
$sortedLowFeatures = @($featureRows | Sort-Object Percent, Found, Feature | Select-Object -First 20)
$zeroCoverageFiles = @(
  $fileRows |
    Where-Object { $_.Found -gt 0 -and $_.Hit -eq 0 } |
    Sort-Object File
)

@("file,percent,hit,found") + ($fileRows | Sort-Object File | ForEach-Object {
  "$($_.File),$($_.Percent),$($_.Hit),$($_.Found)"
}) | Set-Content -Path $fileCsvOut -Encoding UTF8

@("feature,path,percent,hit,found") + ($featureRows | Sort-Object Feature | ForEach-Object {
  "$($_.Feature),$($_.Path),$($_.Percent),$($_.Hit),$($_.Found)"
}) | Set-Content -Path $featureCsvOut -Encoding UTF8

@("file,percent,hit,found") + ($zeroCoverageFiles | ForEach-Object {
  "$($_.File),$($_.Percent),$($_.Hit),$($_.Found)"
}) | Set-Content -Path $zeroCoverageOut -Encoding UTF8

$summary = New-Object System.Collections.Generic.List[string]
$summary.Add("ChronoSpark Coverage Summary")
$summary.Add("Total Coverage: $totalPercent%")
$summary.Add("Lines Hit: $linesHit")
$summary.Add("Lines Found: $linesFound")
$summary.Add("")
$summary.Add("Lowest Feature Coverage:")
$summary.Add("feature,path,percent,hit,found")
foreach ($row in $sortedLowFeatures) {
  $summary.Add("$($row.Feature),$($row.Path),$($row.Percent),$($row.Hit),$($row.Found)")
}
$summary.Add("")
$summary.Add("Lowest File Coverage:")
$summary.Add("file,percent,hit,found")
foreach ($row in $sortedLowFiles) {
  $summary.Add("$($row.File),$($row.Percent),$($row.Hit),$($row.Found)")
}
$summary.Add("")
$summary.Add("Zero Coverage Files:")
$summary.Add("file,percent,hit,found")
if ($zeroCoverageFiles.Count -eq 0) {
  $summary.Add("(none)")
} else {
  foreach ($row in $zeroCoverageFiles) {
    $summary.Add("$($row.File),$($row.Percent),$($row.Hit),$($row.Found)")
  }
}
$summary.Add("")
$summary.Add("Files created:")
$summary.Add("coverage/coverage_summary.txt")
$summary.Add("coverage/coverage_by_feature.csv")
$summary.Add("coverage/coverage_by_file.csv")
$summary.Add("coverage/zero_coverage_files.txt")

$summary | Set-Content -Path $summaryOut -Encoding UTF8
$summary | ForEach-Object { Write-Host $_ }
