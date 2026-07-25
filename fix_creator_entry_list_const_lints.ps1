$ErrorActionPreference = "Stop"

Write-Host "Fixing Creator entry list const lints..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\widgets\creator_entry_lists.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

dart fix --apply $file
dart format $file
flutter analyze lib

Write-Host "Creator entry list const cleanup complete." -ForegroundColor Green
