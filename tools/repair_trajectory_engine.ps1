$ErrorActionPreference = "Stop"

$appFlow = "lib\state\controllers\app_flow_controller.dart"
$screen = "lib\features\trajectory_engine\ui\trajectory_engine_screen.dart"
$shell = "lib\app\navigation_shell.dart"
$importLine = "import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';"

Copy-Item $appFlow "$appFlow.bak_trajectory" -Force
if (Test-Path $screen) { Copy-Item $screen "$screen.bak_trajectory" -Force }
if (Test-Path $shell) { Copy-Item $shell "$shell.bak_trajectory" -Force }

$text = Get-Content $appFlow -Raw

if ($text -notmatch "(?m)^\s*trajectoryEngine,\s*$") {
  $text = $text -replace "(?m)^(\s*)progression,\s*$", "`$1progression,`r`n`$1trajectoryEngine,"
}

$text = $text -replace "void toTrajectoryEngine\(\)\s*=>\s*state\s*=\s*AppView\.[A-Za-z]+;", "void toTrajectoryEngine() => state = AppView.trajectoryEngine;"

Set-Content -Path $appFlow -Value $text -Encoding UTF8

if (Test-Path $screen) {
  $s = Get-Content $screen -Raw
  $s = $s -replace "trajectory\.predictionOutcome,", "trajectory.predictionOutcome ?? 'Future path is stabilizing.',"
  $s = $s -replace "trajectory\.alert,", "trajectory.alert,"
  $s = $s -replace "(\s+)_Bullet\(", "`$1const _Bullet("
  Set-Content -Path $screen -Value $s -Encoding UTF8
}

if (Test-Path $shell) {
  $nav = Get-Content $shell -Raw
  $wired = $false

  if ($nav -notmatch :Escape($importLine)) {
    $nav = $nav -replace "(?m)^(import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';)", "$importLine`r`n`$1"
  }

  if ($nav -notmatch "AppView\.trajectoryEngine") {
    if ($nav -match "case AppView\.progression:") {
      $nav = $nav -replace "(?m)^(\s*)case AppView\.progression:", "`$1case AppView.trajectoryEngine:`r`n`$1  return const TrajectoryEngineScreen();`r`n`$1case AppView.progression:"
      $wired = $true
    }
    elseif ($nav -match "AppView\.progression\s*=>") {
      $nav = $nav -replace "(?m)^(\s*)AppView\.progression\s*=>", "`$1AppView.trajectoryEngine => const TrajectoryEngineScreen(),`r`n`$1AppView.progression =>"
      $wired = $true
    }
  } else {
    $wired = $true
  }

  if (-not $wired) {
    $nav = $nav -replace "(?m)^import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen\.dart';\r?\n", ""
    Write-Host "WARNING: Could not safely wire navigation_shell.dart. Import removed to prevent analyzer error."
  }

  Set-Content -Path $shell -Value $nav -Encoding UTF8
}

dart format $appFlow
if (Test-Path $screen) { dart format $screen }
if (Test-Path $shell) { dart format $shell }

flutter analyze
