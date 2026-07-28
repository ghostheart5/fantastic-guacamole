$ErrorActionPreference = "Continue"

New-Item -ItemType Directory -Force .\coverage | Out-Null

$summaryPath = ".\coverage\coverage_summary.txt"
$fileReportPath = ".\coverage\coverage_by_file.txt"
$folderReportPath = ".\coverage\coverage_by_folder.txt"
$inventoryPath = ".\coverage\test_inventory.txt"

"=== TEST INVENTORY ===" | Set-Content $inventoryPath
"Generated: $(Get-Date)" | Add-Content $inventoryPath
"" | Add-Content $inventoryPath

Get-ChildItem .\test -Recurse -File |
  Sort-Object FullName |
  ForEach-Object {
    $_.FullName.Replace((Resolve-Path ".").Path + "\", "") | Add-Content $inventoryPath
  }

flutter test --coverage

$lcovPath = ".\coverage\lcov.info"

if (!(Test-Path $lcovPath)) {
  "[FAIL] coverage/lcov.info was not created." | Set-Content $summaryPath
  exit 1
}

$coverageMap = @{}
$currentFile = $null
$totalLines = 0
$coveredLines = 0

foreach ($line in Get-Content $lcovPath) {
  if ($line.StartsWith("SF:")) {
    $currentFile = $line.Substring(3).Replace("\", "/")
    $totalLines = 0
    $coveredLines = 0
    continue
  }

  if ($line.StartsWith("DA:")) {
    $parts = $line.Substring(3).Split(",")
    if ($parts.Count -ge 2) {
      $totalLines++
      if ([int]$parts[1] -gt 0) {
        $coveredLines++
      }
    }
    continue
  }

  if ($line -eq "end_of_record") {
    if ($currentFile -ne $null) {
      $relativeFile = $currentFile
      $libIndex = $relativeFile.IndexOf("lib/")
      if ($libIndex -ge 0) {
        $relativeFile = $relativeFile.Substring($libIndex)
      }

      if ($relativeFile.StartsWith("lib/")) {
        $coverageMap[$relativeFile] = [pscustomobject]@{
          Covered = $coveredLines
          Total = $totalLines
        }
      }
    }

    $currentFile = $null
    $totalLines = 0
    $coveredLines = 0
  }
}

$records = @()

Get-ChildItem .\lib -Recurse -File -Filter *.dart |
  Where-Object {
    $_.Name -notmatch "\.g\.dart$" -and
    $_.Name -notmatch "\.freezed\.dart$" -and
    $_.Name -notmatch "\.mocks\.dart$"
  } |
  ForEach-Object {
    $relative = $_.FullName.Replace((Resolve-Path ".").Path + "\", "").Replace("\", "/")
    $folder = Split-Path $relative -Parent
    $folder = $folder.Replace("\", "/")

    $covered = 0
    $total = 0

    if ($coverageMap.ContainsKey($relative)) {
      $covered = $coverageMap[$relative].Covered
      $total = $coverageMap[$relative].Total
    }

    $percent = 0
    if ($total -gt 0) {
      $percent = :Round(($covered / $total) * 100, 2)
    }

    $records += [pscustomobject]@{
      File = $relative
      Folder = $folder
      Covered = $covered
      Total = $total
      Percent = $percent
    }
  }

"=== COVERAGE BY FILE ===" | Set-Content $fileReportPath
"Generated: $(Get-Date)" | Add-Content $fileReportPath
"" | Add-Content $fileReportPath

$records |
  Sort-Object Percent, File |
  ForEach-Object {
    "{0,7:N2}%  {1,5}/{2,-5}  {3}" -f $_.Percent, $_.Covered, $_.Total, $_.File |
      Add-Content $fileReportPath
  }

"=== COVERAGE BY FOLDER ===" | Set-Content $folderReportPath
"Generated: $(Get-Date)" | Add-Content $folderReportPath
"" | Add-Content $folderReportPath

$records |
  Group-Object Folder |
  Sort-Object Name |
  ForEach-Object {
    $covered = ($_.Group | Measure-Object Covered -Sum).Sum
    $total = ($_.Group | Measure-Object Total -Sum).Sum
    $percent = 0

    if ($total -gt 0) {
      $percent = :Round(($covered / $total) * 100, 2)
    }

    "{0,7:N2}%  {1,5}/{2,-5}  {3}" -f $percent, $covered, $total, $_.Name |
      Add-Content $folderReportPath
  }

$totalCovered = ($records | Measure-Object Covered -Sum).Sum
$totalCoverable = ($records | Measure-Object Total -Sum).Sum
$totalFiles = $records.Count
$zeroFiles = ($records | Where-Object { $_.Percent -eq 0 }).Count
$totalPercent = 0

if ($totalCoverable -gt 0) {
  $totalPercent = :Round(($totalCovered / $totalCoverable) * 100, 2)
}

"=== COVERAGE SUMMARY ===" | Set-Content $summaryPath
"Generated: $(Get-Date)" | Add-Content $summaryPath
"" | Add-Content $summaryPath
"Lib files measured: $totalFiles" | Add-Content $summaryPath
"Files at 0 percent: $zeroFiles" | Add-Content $summaryPath
"Lines covered: $totalCovered" | Add-Content $summaryPath
"Lines total: $totalCoverable" | Add-Content $summaryPath
"Overall coverage: $totalPercent%" | Add-Content $summaryPath
"" | Add-Content $summaryPath
"Reports:" | Add-Content $summaryPath
"- coverage/test_inventory.txt" | Add-Content $summaryPath
"- coverage/coverage_by_file.txt" | Add-Content $summaryPath
"- coverage/coverage_by_folder.txt" | Add-Content $summaryPath

Write-Host "[DONE] Coverage report created." -ForegroundColor Green
Write-Host "Summary: coverage\coverage_summary.txt" -ForegroundColor Cyan
Write-Host "By folder: coverage\coverage_by_folder.txt" -ForegroundColor Cyan
Write-Host "By file: coverage\coverage_by_file.txt" -ForegroundColor Cyan

