$ErrorActionPreference = "Stop"

Write-Host "Removing duplicate onEdit wiring..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\widgets\creator_entry_lists.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

Copy-Item $file "$file.bak_duplicate_onedit" -Force

$text = Get-Content $file -Raw

# Remove duplicated constructor parameter lines.
# Handles repeated:
# required this.onEdit,
# required this.onEdit,
$text = [System.Text.RegularExpressions.Regex]::Replace(
  $text,
  "(?m)^(\s*required this\.onEdit,\r?\n)(\s*required this\.onEdit,\r?\n)+",
  '$1'
)

# Remove duplicated field declarations.
# Handles repeated:
# final ValueChanged<Task> onEdit;
# final ValueChanged<Task> onEdit;
$text = [System.Text.RegularExpressions.Regex]::Replace(
  $text,
  "(?m)^(\s*final ValueChanged<Task> onEdit;\r?\n)(\s*final ValueChanged<Task> onEdit;\r?\n)+",
  '$1'
)

# Handles repeated:
# final VoidCallback onEdit;
# final VoidCallback onEdit;
$text = [System.Text.RegularExpressions.Regex]::Replace(
  $text,
  "(?m)^(\s*final VoidCallback onEdit;\r?\n)(\s*final VoidCallback onEdit;\r?\n)+",
  '$1'
)

# Handles repeated:
# final Future<void> Function() onEdit;
# final Future<void> Function() onEdit;
$text = [System.Text.RegularExpressions.Regex]::Replace(
  $text,
  "(?m)^(\s*final Future<void> Function\(\) onEdit;\r?\n)(\s*final Future<void> Function\(\) onEdit;\r?\n)+",
  '$1'
)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $text, $utf8NoBom)

Write-Host "Formatting Creator entry lists..." -ForegroundColor Cyan
dart format $file

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Duplicate onEdit cleanup complete." -ForegroundColor Green
