$ErrorActionPreference = "Stop"

Write-Host "Restoring internal Soul Map dependencies from dead-code archive..." -ForegroundColor Cyan

$archives = Get-ChildItem . -Directory |
  Where-Object { $_.Name -like ".dead_code_archive_lib_only_*" -or $_.Name -like ".dead_code_archive_*" } |
  Sort-Object LastWriteTime -Descending

if (-not $archives) {
  throw "No dead-code archive folders found."
}

$restored = 0

foreach ($archive in $archives) {
  Write-Host "Checking archive: $($archive.FullName)" -ForegroundColor Yellow

  $soulFiles = Get-ChildItem $archive.FullName -Recurse -File |
    Where-Object {
      $_.Name -like "*soul_map*" -or
      $_.FullName -like "*soul_map_models.dart*" -or
      $_.FullName -like "*soul_map_provider.dart*"
    }

  foreach ($file in $soulFiles) {
    $name = $file.Name

    if ($name -like "*soul_map_models.dart*") {
      $target = ".\lib\state\models\soul_map_models.dart"
    }
    elseif ($name -like "*soul_map_provider.dart*") {
      $target = ".\lib\state\providers\soul_map_provider.dart"
    }
    else {
      continue
    }

    $targetDir = Split-Path $target -Parent
    if (-not (Test-Path $targetDir)) {
      New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    Copy-Item $file.FullName $target -Force
    Write-Host "Restored: $target" -ForegroundColor Green
    $restored++
  }

  if ($restored -gt 0) {
    break
  }
}

if ($restored -eq 0) {
  throw "Could not find archived soul_map_models.dart or soul_map_provider.dart."
}

Write-Host ""
Write-Host "Formatting restored files..." -ForegroundColor Cyan
dart format .\lib\state\models\soul_map_models.dart .\lib\state\providers\soul_map_provider.dart

Write-Host ""
Write-Host "Analyzing lib..." -ForegroundColor Cyan
flutter analyze lib

Write-Host ""
Write-Host "Internal Soul Map dependencies restored. Soul Map remains removed as a user-facing screen." -ForegroundColor Green
