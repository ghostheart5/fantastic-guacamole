$ErrorActionPreference = "Stop"

$file = ".\lib\app\navigation_shell.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

$text = Get-Content $file -Raw

Write-Host "Cleaning unreachable removed AppView cases in navigation_shell.dart..." -ForegroundColor Cyan

# Remove any remaining switch cases for deleted views.
# Handles:
# case AppView.logs:
#   ...
# case AppView.soulMap:
#   ...
#
# Stops before the next case/default/closing switch boundary.
$text = :Replace(
  $text,
  "(?ms)^\s*case\s+AppView\.logs\s*:\s*.*?(?=^\s*(case\s+AppView\.|default\s*:|}\s*$))",
  ""
)

$text = :Replace(
  $text,
  "(?ms)^\s*case\s+AppView\.soulMap\s*:\s*.*?(?=^\s*(case\s+AppView\.|default\s*:|}\s*$))",
  ""
)

# Remove modern pattern-switch versions if present:
# AppView.logs => ...
# AppView.soulMap => ...
$text = :Replace(
  $text,
  "(?m)^\s*AppView\.logs\s*=>\s*[^,;]+[,;]\s*",
  ""
)

$text = :Replace(
  $text,
  "(?m)^\s*AppView\.soulMap\s*=>\s*[^,;]+[,;]\s*",
  ""
)

# Remove direct references if any survived.
$text = $text -replace "AppView\.logs", "AppView.nexus"
$text = $text -replace "AppView\.soulMap", "AppView.nexus"

Set-Content $file $text -NoNewline

Write-Host "Cleanup complete." -ForegroundColor Green
Write-Host ""
Write-Host "Remaining deleted-view references:" -ForegroundColor Cyan

Select-String -Path .\lib\**\*.dart,.\test\**\*.dart -Pattern "AppView\.logs|AppView\.soulMap|toLogs|toSoulMap" -ErrorAction SilentlyContinue |
  Select-Object Path, LineNumber, Line

Write-Host ""
Write-Host "Navigation shell around warning area:" -ForegroundColor Cyan
Get-Content $file | Select-Object -Skip 470 -First 35

Write-Host ""
Write-Host "Now run: flutter analyze" -ForegroundColor Yellow
