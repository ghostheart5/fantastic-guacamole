$ErrorActionPreference = "Stop"

Write-Host "Running Dart automatic fixes for Creator workbench..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\widgets\creator_unified_workbench.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

# Let Dart fix prefer_const_constructors / unnecessary_const correctly.
dart fix --apply $file

Write-Host "Formatting Creator workbench..." -ForegroundColor Cyan
dart format $file

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator workbench lint cleanup complete." -ForegroundColor Green
