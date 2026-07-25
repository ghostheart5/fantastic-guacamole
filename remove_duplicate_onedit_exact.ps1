$ErrorActionPreference = "Stop"

Write-Host "Removing duplicate onEdit constructor parameters by line cleanup..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\widgets\creator_entry_lists.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

Copy-Item $file "$file.bak_remove_duplicate_onedit_exact" -Force

$lines = Get-Content $file
$output = New-Object System.Collections.Generic.List[string]

$insideConstructor = $false
$currentConstructor = ""
$seenOnEdit = $false

foreach ($line in $lines) {
  if ($line -match "^\s*const _CreatorEntryGroup\(\{") {
    $insideConstructor = $true
    $currentConstructor = "_CreatorEntryGroup"
    $seenOnEdit = $false
    $output.Add($line)
    continue
  }

  if ($line -match "^\s*const _CreatorEntryTile\(\{") {
    $insideConstructor = $true
    $currentConstructor = "_CreatorEntryTile"
    $seenOnEdit = $false
    $output.Add($line)
    continue
  }

  if ($insideConstructor -and $line -match "^\s*\}\);") {
    $insideConstructor = $false
    $currentConstructor = ""
    $seenOnEdit = $false
    $output.Add($line)
    continue
  }

  if ($insideConstructor -and $line -match "^\s*required this\.onEdit,\s*$") {
    if ($seenOnEdit) {
      Write-Host "Removed duplicate onEdit in $currentConstructor" -ForegroundColor Yellow
      continue
    }

    $seenOnEdit = $true
    $output.Add($line)
    continue
  }

  $output.Add($line)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($file, $output, $utf8NoBom)

Write-Host "Formatting Creator entry lists..." -ForegroundColor Cyan
dart format $file

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Duplicate onEdit parameters removed." -ForegroundColor Green
