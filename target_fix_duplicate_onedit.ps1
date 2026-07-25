$ErrorActionPreference = "Stop"

Write-Host "Target-fixing duplicate onEdit constructor parameters..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\widgets\creator_entry_lists.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

Copy-Item $file "$file.bak_target_onedit_fix" -Force

$text = Get-Content $file -Raw

function Fix-OnEditConstructor {
  param(
    [string]$Source,
    [string]$ConstructorName
  )

  $pattern = "(?s)(const $ConstructorName\(\{\s*)(.*?)(\s*\}\);)"

  return [System.Text.RegularExpressions.Regex]::Replace(
    $Source,
    $pattern,
    {
      param($m)

      $start = $m.Groups[1].Value
      $body = $m.Groups[2].Value
      $end = $m.Groups[3].Value

      # Remove every existing onEdit constructor param.
      $body = [System.Text.RegularExpressions.Regex]::Replace(
        $body,
        "(?m)^\s*required this\.onEdit,\r?\n",
        ""
      )

      # Insert exactly one onEdit after onOpen.
      $body = [System.Text.RegularExpressions.Regex]::Replace(
        $body,
        "(?m)^(\s*required this\.onOpen,\r?\n)",
        "`$1    required this.onEdit,`r`n",
        1
      )

      return $start + $body + $end
    }
  )
}

function Fix-OnEditFields {
  param(
    [string]$Source
  )

  # Collapse any duplicate fields of all possible onEdit types.
  $Source = [System.Text.RegularExpressions.Regex]::Replace(
    $Source,
    "(?m)^(\s*final ValueChanged<Task> onEdit;\r?\n)+",
    "  final ValueChanged<Task> onEdit;`r`n"
  )

  $Source = [System.Text.RegularExpressions.Regex]::Replace(
    $Source,
    "(?m)^(\s*final VoidCallback onEdit;\r?\n)+",
    "  final VoidCallback onEdit;`r`n"
  )

  $Source = [System.Text.RegularExpressions.Regex]::Replace(
    $Source,
    "(?m)^(\s*final Future<void> Function\(\) onEdit;\r?\n)+",
    "  final Future<void> Function() onEdit;`r`n"
  )

  return $Source
}

$text = Fix-OnEditConstructor -Source $text -ConstructorName "_CreatorEntryGroup"
$text = Fix-OnEditConstructor -Source $text -ConstructorName "_CreatorEntryTile"
$text = Fix-OnEditConstructor -Source $text -ConstructorName "_CreatorEntryDetailSheet"
$text = Fix-OnEditFields -Source $text

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $text, $utf8NoBom)

Write-Host "Formatting Creator entry lists..." -ForegroundColor Cyan
dart format $file

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Target duplicate onEdit fix complete." -ForegroundColor Green
