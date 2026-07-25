$ErrorActionPreference = "Stop"

Write-Host "Fixing Creator const lint warnings..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\widgets\creator_unified_workbench.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

$text = Get-Content $file -Raw

# Add const to activity items where analyzer requested it.
$text = $text -replace "(?m)^(\s*)_CreatorActivityItem\(", '$1const _CreatorActivityItem('

# Add const to simple SizedBox height spacers.
$text = $text -replace "(?m)^(\s*)SizedBox\(height: 8\),", '$1const SizedBox(height: 8),'

# Safety: prevent accidental duplicate const.
$text = $text -replace "const const ", "const "

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $text, $utf8NoBom)

Write-Host "Formatting Creator workbench..." -ForegroundColor Cyan
dart format $file

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator const lint cleanup complete." -ForegroundColor Green
