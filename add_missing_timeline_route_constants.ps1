$ErrorActionPreference = "Stop"

Write-Host "Adding missing RoutePaths.timeline constants safely..." -ForegroundColor Cyan

$routeFile = ".\lib\app\router\route_paths.dart"
$routerFile = ".\lib\app\router\app_router.dart"

if (-not (Test-Path $routeFile)) {
  throw "Missing route paths file: $routeFile"
}

if (-not (Test-Path $routerFile)) {
  throw "Missing app router file: $routerFile"
}

Copy-Item $routeFile "$routeFile.bak_add_timeline_constant" -Force
Copy-Item $routerFile "$routerFile.bak_add_timeline_constant" -Force

$lines = Get-Content $routeFile
$out = New-Object System.Collections.Generic.List[string]

$hasTimeline = $false
$hasLegacyTimeline = $false

foreach ($line in $lines) {
  if ($line -match "static const timeline\s*=") {
    $hasTimeline = $true
  }

  if ($line -match "static const legacyTimeline\s*=") {
    $hasLegacyTimeline = $true
  }
}

foreach ($line in $lines) {
  $out.Add($line)

  if (-not $hasTimeline -and $line -match "static const advancedRoot\s*=") {
    $out.Add("  static const timeline = '/settings/advanced/logs';")
    $hasTimeline = $true
  }

  if (-not $hasLegacyTimeline -and $line -match "static const legacyCoach\s*=") {
    $out.Add("  static const legacyTimeline = '/logs';")
    $hasLegacyTimeline = $true
  }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($routeFile, $out, $utf8NoBom)

# Make sure router references use the new constants.
$router = Get-Content $routerFile -Raw
$router = $router.Replace("RoutePaths.logs", "RoutePaths.timeline")
$router = $router.Replace("RoutePaths.legacyLogs", "RoutePaths.legacyTimeline")
[System.IO.File]::WriteAllText($routerFile, $router, $utf8NoBom)

Write-Host "Formatting route files..." -ForegroundColor Cyan
dart format $routeFile $routerFile

Write-Host "Verifying constants..." -ForegroundColor Cyan
Select-String -Path $routeFile -Pattern "timeline|legacyTimeline"

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Timeline route constants added successfully." -ForegroundColor Green
