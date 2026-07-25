$ErrorActionPreference = "Stop"

Write-Host "Safely removing user-facing Logs and Activity Ledger navigation..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$targets = @(
  ".\lib\app\navigation_shell.dart",
  ".\lib\app\router\app_router.dart",
  ".\lib\state\controllers\app_flow_controller.dart",
  ".\lib\features\timeline\ui\timeline_screen.dart"
)

foreach ($file in $targets) {
  if (-not (Test-Path $file)) {
    Write-Host "Skipping missing file: $file" -ForegroundColor Yellow
    continue
  }

  $text = Get-Content $file -Raw
  $original = $text

  # Route old logs view calls to Timeline if Timeline exists, otherwise Nexus.
  $text = $text.Replace("AppView.logs", "AppView.timeline")
  $text = $text.Replace(".toLogs()", ".toTimeline()")

  # User-facing labels only.
  $text = $text.Replace("ACTIVITY LEDGER", "TIMELINE")
  $text = $text.Replace("Activity Ledger", "Timeline")
  $text = $text.Replace("activity ledger", "timeline")
  $text = $text.Replace("LOGS", "TIMELINE")
  $text = $text.Replace("Logs", "Timeline")

  # Remove old LogsScreen import only.
  $text = [System.Text.RegularExpressions.Regex]::Replace(
    $text,
    "(?m)^import 'package:fantastic_guacamole/.*/logs_screen\.dart';\r?\n",
    ""
  )

  # Remove old Activity Ledger imports only.
  $text = [System.Text.RegularExpressions.Regex]::Replace(
    $text,
    "(?m)^import 'package:fantastic_guacamole/.*/activity_ledger.*\.dart';\r?\n",
    ""
  )

  if ($text -ne $original) {
    [System.IO.File]::WriteAllText($file, $text, $utf8NoBom)
    Write-Host "Updated: $file" -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "Checking remaining user-facing old history routes..." -ForegroundColor Cyan

Select-String -Path .\lib\**\*.dart `
-Pattern "AppView\.logs|toLogs\(|LogsScreen|logs_screen|Activity Ledger|ACTIVITY LEDGER" `
-ErrorAction SilentlyContinue |
Select-Object Path,LineNumber,Line

Write-Host ""
Write-Host "Formatting app code..." -ForegroundColor Cyan
dart format .\lib

Write-Host ""
Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host ""
Write-Host "Safe Timeline history cleanup complete." -ForegroundColor Green
