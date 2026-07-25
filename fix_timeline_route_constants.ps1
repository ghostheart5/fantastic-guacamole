$ErrorActionPreference = "Stop"

Write-Host "Adding Timeline route constants and fixing router references..." -ForegroundColor Cyan

$routeFile = ".\lib\app\router\route_paths.dart"
$routerFile = ".\lib\app\router\app_router.dart"

if (-not (Test-Path $routeFile)) {
  throw "Missing route paths file: $routeFile"
}

if (-not (Test-Path $routerFile)) {
  throw "Missing app router file: $routerFile"
}

Copy-Item $routeFile "$routeFile.bak_timeline_routes" -Force
Copy-Item $routerFile "$routerFile.bak_timeline_routes" -Force

$routeText = Get-Content $routeFile -Raw
$routerText = Get-Content $routerFile -Raw

# Add timeline route constants while preserving old logs aliases.
if ($routeText -notmatch "static const timeline =") {
  $routeText = $routeText.Replace(
"  static const logs = '$advancedRoot/logs';",
"  static const timeline = '$advancedRoot/logs';
  static const logs = timeline;"
  )
}

if ($routeText -notmatch "static const legacyTimeline =") {
  $routeText = $routeText.Replace(
"  static const legacyLogs = '/logs';",
"  static const legacyTimeline = '/logs';
  static const legacyLogs = legacyTimeline;"
  )
}

# Now RoutePaths.timeline and RoutePaths.legacyTimeline are valid.
$routerText = $routerText.Replace("RoutePaths.logs", "RoutePaths.timeline")
$routerText = $routerText.Replace("RoutePaths.legacyLogs", "RoutePaths.legacyTimeline")

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($routeFile, $routeText, $utf8NoBom)
[System.IO.File]::WriteAllText($routerFile, $routerText, $utf8NoBom)

Write-Host "Formatting route files..." -ForegroundColor Cyan
dart format $routeFile $routerFile

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Timeline route constants fixed." -ForegroundColor Green
