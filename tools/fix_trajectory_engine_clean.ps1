$ErrorActionPreference = "Stop"

$appFlow = "lib\state\controllers\app_flow_controller.dart"
$screen = "lib\features\trajectory_engine\ui\trajectory_engine_screen.dart"
$importLine = "import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';"

if (-not (Test-Path $appFlow)) {
  throw "Missing $appFlow"
}

if (-not (Test-Path $screen)) {
  throw "Missing $screen"
}

Copy-Item $appFlow "$appFlow.bak_fix_traj" -Force
Copy-Item $screen "$screen.bak_fix_traj" -Force

$app = Get-Content $appFlow -Raw

if ($app -notmatch "(?m)^\s*trajectoryEngine,\s*$") {
  $app = $app -replace "(?m)^(\s*)progression,\s*$", "`$1progression,`r`n`$1trajectoryEngine,"
}

$app = $app -replace "void toTrajectoryEngine\(\)\s*=>\s*state\s*=\s*AppView\.[A-Za-z]+;", "void toTrajectoryEngine() => state = AppView.trajectoryEngine;"

Set-Content -Path $appFlow -Value $app -Encoding UTF8

$s = Get-Content $screen -Raw
$s = $s -replace "trajectory\.predictionOutcome,", "trajectory.predictionOutcome ?? 'Future path is stabilizing.',"
$s = $s -replace "_Bullet\('Predict collapses before they hit\.'\)", "const _Bullet('Predict collapses before they hit.')"
$s = $s -replace "_Bullet\('Detect rising momentum\.'\)", "const _Bullet('Detect rising momentum.')"
$s = $s -replace "_Bullet\('Measure alignment and behavioral drift\.'\)", "const _Bullet('Measure alignment and behavioral drift.')"
$s = $s -replace "_Bullet\('Reward divergence toward a better future path\.'\)", "const _Bullet('Reward divergence toward a better future path.')"
$s = $s -replace "_Bullet\('Stabilize volatility\.'\)", "const _Bullet('Stabilize volatility.')"
$s = $s -replace "_Bullet\('Build XP from future-based behavior\.'\)", "const _Bullet('Build XP from future-based behavior.')"
Set-Content -Path $screen -Value $s -Encoding UTF8

$wired = $false
$dartFiles = Get-ChildItem -Path "lib" -Recurse -Filter "*.dart"

foreach ($file in $dartFiles) {
  if ($file.FullName -like "*app_flow_controller.dart") {
    continue
  }

  $content = Get-Content $file.FullName -Raw

  if ($content -match "AppView\.progression" -and $content -notmatch "AppView\.trajectoryEngine") {
    $original = $content

    if ($content -match "case AppView\.progression:") {
      if (-not $content.Contains($importLine)) {
        $content = $importLine + "`r`n" + $content
      }

      $content = $content -replace "(?m)^(\s*)case AppView\.progression:", "`$1case AppView.trajectoryEngine:`r`n`$1  return const TrajectoryEngineScreen();`r`n`$1case AppView.progression:"
      Set-Content -Path $file.FullName -Value $content -Encoding UTF8
      Write-Host "Wired trajectoryEngine in $($file.FullName)"
      $wired = $true
      break
    }

    if ($content -match "AppView\.progression\s*=>") {
      if (-not $content.Contains($importLine)) {
        $content = $importLine + "`r`n" + $content
      }

      $content = $content -replace "(?m)^(\s*)AppView\.progression\s*=>", "`$1AppView.trajectoryEngine => const TrajectoryEngineScreen(),`r`n`$1AppView.progression =>"
      Set-Content -Path $file.FullName -Value $content -Encoding UTF8
      Write-Host "Wired trajectoryEngine in $($file.FullName)"
      $wired = $true
      break
    }
  }
}

if (-not $wired) {
  Write-Host "WARNING: Could not auto-find AppView renderer."
  Write-Host "AppFlow and TrajectoryEngineScreen were fixed, but screen mapping still needs manual wiring."
}

dart format $appFlow
dart format $screen

if ($wired) {
  dart format lib
}

flutter analyze

if ($LASTEXITCODE -eq 0) {
  flutter build apk --debug
}
