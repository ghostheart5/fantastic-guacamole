$ErrorActionPreference = "Stop"

Write-Host "Restoring files from timeline cleanup backup..." -ForegroundColor Cyan

$backupDir = ".\backup_timeline_history_cleanup"

if (-not (Test-Path $backupDir)) {
  throw "Backup folder not found: $backupDir"
}

Get-ChildItem $backupDir -File | ForEach-Object {
  $relative = $_.Name.Replace("__", "\")
  $target = Join-Path "." $relative
  $targetDir = Split-Path $target -Parent

  if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }

  Copy-Item $_.FullName $target -Force
  Write-Host "Restored: $target" -ForegroundColor Green
}

Write-Host ""
Write-Host "Formatting restored app files..." -ForegroundColor Cyan
dart format .\lib

Write-Host ""
Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host ""
Write-Host "Restore complete." -ForegroundColor Green
