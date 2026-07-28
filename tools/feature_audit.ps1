Write-Host ""
Write-Host "===== CHRONOSPARK FEATURE AUDIT ====="
Write-Host ""

$Features = @(
    "nexus",
    "home",
    "creator",
    "timeline",
    "progression",
    "trajectory_engine",
    "si_console",
    "profile"
)

foreach ($Feature in $Features) {

    $Files = Get-ChildItem .\lib -Recurse -File -Filter *.dart |
        Where-Object { $_.FullName -match [regex]::Escape($Feature) }

    Write-Host ""
    Write-Host "--------*-----------------------"
    Write-Host "FEATURE: $Feature"
    Write-Host "----------------------------*---"

    Write-Host "Files:" $Files.Count

    $Providers = Select-String `
        -Path .\lib\state\providers\*.dart `
        -Pattern $Feature `
        -SimpleMatch `
        -ErrorAction SilentlyContinue

    Write-Host "Provider refs:" $Providers.Count

    $Controllers = Select-String `
        -Path .\lib\state\controllers\*.dart `
        -Pattern $Feature `
        -SimpleMatch `
        -ErrorAction SilentlyContinue

    Write-Host "Controller refs:" $Controllers.Count
}
Write-Host ""
Write-Host "===== APP VIEW ====="

findstr /N /I "AppView" `
lib\state\controllers\app_flow_controller.dart

Write-Host ""
Write-Host "===== NEXUS ROUTES ====="
findstr /S /I `
"toSmartCoach toCreator toTimeline toProgression toTrajectoryEngine toProfile toConsole" `
lib\features\nexus\ui\*.dart

Write-Host ""
Write-Host "===== TRAJECTORY ====="

findstr /S /I `
"trajectoryEngine TrajectoryEngineScreen trajectorySummaryProvider" `
lib\features\trajectory_engine\*.dart

Write-Host ""
Write-Host "===== ANALYZE ====="

flutter analyze