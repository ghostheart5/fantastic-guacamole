$ErrorActionPreference = "Stop"

Write-Host "Restoring DynamicForm and stabilizing Creator..." -ForegroundColor Cyan

$formPath = ".\lib\features\creator\widgets\dynamic_form.dart"
$backupPath = ".\lib\features\creator\widgets\dynamic_form.dart.bak_mode"
$screenPath = ".\lib\features\creator\ui\creator_screen.dart"

if (-not (Test-Path $backupPath)) {
  throw "Missing backup file: $backupPath"
}

if (-not (Test-Path $screenPath)) {
  throw "Missing CreatorScreen file: $screenPath"
}

Copy-Item $backupPath $formPath -Force
Write-Host "Restored dynamic_form.dart from backup." -ForegroundColor Green

$screen = Get-Content $screenPath -Raw

# Remove the workspaceMode argument because the restored DynamicForm does not support it.
$screen = $screen -replace "\s*workspaceMode:\s*_mode,\s*", "`r`n"

# Keep Creator mode state and workbench UI intact.
# DynamicForm will stay task-backed for now until we wire mode safely through CreatorFormData.

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($screenPath, $screen, $utf8NoBom)

Write-Host "Formatting Creator files..." -ForegroundColor Cyan
dart format .\lib\features\creator

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator restored to stable mode." -ForegroundColor Green
