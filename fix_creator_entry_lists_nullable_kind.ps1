$ErrorActionPreference = "Stop"

Write-Host "Fixing nullable kind handling in Creator entry lists..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\widgets\creator_entry_lists.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

$text = Get-Content $file -Raw

# Replace direct nullable kind usage in filters.
$text = $text.Replace(
"task.kind.trim().toLowerCase() == 'goal'",
"(task.kind ?? '').trim().toLowerCase() == 'goal'"
)

$text = $text.Replace(
"task.kind.trim().toLowerCase() == 'milestone'",
"(task.kind ?? '').trim().toLowerCase() == 'milestone'"
)

$text = $text.Replace(
"task.kind.trim().toLowerCase() == 'plan'",
"(task.kind ?? '').trim().toLowerCase() == 'plan'"
)

# Replace static helper parameter from String to String?.
$text = $text.Replace(
"static bool _isCreatorSpecialKind(String kind) {",
"static bool _isCreatorSpecialKind(String? kind) {"
)

$text = $text.Replace(
"final String normalized = kind.trim().toLowerCase();",
"final String normalized = (kind ?? '').trim().toLowerCase();"
)

# Replace tile kind display.
$text = $text.Replace(
"entry.kind.toUpperCase(),",
"(entry.kind ?? 'task').toUpperCase(),"
)

# Let Dart clean const lint.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $text, $utf8NoBom)

Write-Host "Formatting Creator entry lists..." -ForegroundColor Cyan
dart format $file

Write-Host "Applying Dart fixes..." -ForegroundColor Cyan
dart fix --apply $file

Write-Host "Formatting again..." -ForegroundColor Cyan
dart format $file

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator entry list nullable kind fix complete." -ForegroundColor Green
