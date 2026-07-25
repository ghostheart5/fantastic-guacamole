$ErrorActionPreference = "Stop"

Write-Host "Fixing missing Timeline asset and legacy route references..." -ForegroundColor Cyan

$navFile = ".\lib\app\navigation_shell.dart"
$routerFile = ".\lib\app\router\app_router.dart"

if (-not (Test-Path $navFile)) {
  throw "Missing navigation shell: $navFile"
}

if (-not (Test-Path $routerFile)) {
  throw "Missing router file: $routerFile"
}

Copy-Item $navFile "$navFile.bak_timeline_icons" -Force
Copy-Item $routerFile "$routerFile.bak_timeline_routes" -Force

$nav = Get-Content $navFile -Raw
$router = Get-Content $routerFile -Raw

# AppAssets.iconTimeline does not exist. Use a known existing task/history-style asset.
# If your app has a better timeline icon later, swap this manually.
$nav = $nav.Replace("AppAssets.iconTimeline", "AppAssets.iconTasks")

# RoutePaths.legacyTimeline does not exist. Route old legacy timeline references to main timeline path.
$router = $router.Replace("RoutePaths.legacyTimeline", "RoutePaths.timeline")

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($navFile, $nav, $utf8NoBom)
[System.IO.File]::WriteAllText($routerFile, $router, $utf8NoBom)

Write-Host "Formatting changed files..." -ForegroundColor Cyan
dart format $navFile $routerFile

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Timeline references fixed." -ForegroundColor Green
