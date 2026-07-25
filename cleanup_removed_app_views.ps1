$ErrorActionPreference = "Stop"

Write-Host "Cleaning removed AppView routes: logs + soulMap..." -ForegroundColor Cyan

$files = @(
  ".\lib\app\navigation_shell.dart",
  ".\lib\app\router\app_router.dart",
  ".\lib\features\home\ui\smart_coach_screen.dart",
  ".\test\controllers\controller_smoke_test.dart",
  ".\test\controllers\controller_transition_stress_test.dart",
  ".\test\navigation\app_flow_navigation_test.dart",
  ".\test\navigation\navigation_shell_back_test.dart",
  ".\test\navigation\navigation_shell_open_views_test.dart"
)

foreach ($file in $files) {
  if (-not (Test-Path $file)) {
    Write-Host "Skipping missing file: $file" -ForegroundColor Yellow
    continue
  }

  $text = Get-Content $file -Raw

  # Remove direct method calls.
  $text = $text -replace "ref\.read\(appFlowProvider\.notifier\)\.toSoulMap\(\)", "ref.read(appFlowProvider.notifier).toNexus()"
  $text = $text -replace "ref\.read\(appFlowProvider\.notifier\)\.toLogs\(\)", "ref.read(appFlowProvider.notifier).toNexus()"
  $text = $text -replace "\.toSoulMap\(\)", ".toNexus()"
  $text = $text -replace "\.toLogs\(\)", ".toNexus()"

  # Replace enum references in tests/router with an existing safe landing view.
  $text = $text -replace "AppView\.soulMap", "AppView.nexus"
  $text = $text -replace "AppView\.logs", "AppView.nexus"

  # Remove obvious route names if used as plain strings in tests or router extras.
  $text = $text -replace "'soulMap'", "'nexus'"
  $text = $text -replace '"soulMap"', '"nexus"'
  $text = $text -replace "'logs'", "'nexus'"
  $text = $text -replace '"logs"', '"nexus"'

  Set-Content $file $text -NoNewline
}

Write-Host "Primary cleanup complete." -ForegroundColor Green

Write-Host "Remaining references:" -ForegroundColor Cyan
Select-String -Path .\lib\**\*.dart,.\test\**\*.dart -Pattern "toSoulMap|toLogs|AppView\.soulMap|AppView\.logs|case AppView\.soulMap|case AppView\.logs" -ErrorAction SilentlyContinue |
  Select-Object Path, LineNumber, Line

Write-Host "Now run: flutter analyze" -ForegroundColor Cyan
