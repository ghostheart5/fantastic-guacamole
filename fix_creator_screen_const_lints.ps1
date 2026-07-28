$ErrorActionPreference = "Stop"

Write-Host "Fixing CreatorScreen const lints..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\creator_screen.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

Copy-Item $file "$file.bak_creator_const_lints" -Force

$text = Get-Content $file -Raw

# Fix SnackBar const lint after dynamic message was changed.
$text = $text.Replace(
"                          SnackBar(
                            content: Text('${_mode.name} entry saved.'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),",
"                          SnackBar(
                            content: Text('${_mode.name} entry saved.'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),"
)

# Let Dart apply exact const fixes safely.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $text, $utf8NoBom)

dart fix --apply $file
dart format $file
flutter analyze lib

Write-Host "CreatorScreen const lint cleanup complete." -ForegroundColor Green
