$Report = "feature_wiring_audit.txt"

"=========================================" | Set-Content $Report
"CHRONOSPARK FEATURE WIRING AUDIT" | Add-Content $Report
"=========================================" | Add-Content $Report
"" | Add-Content $Report

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

    "" | Add-Content $Report
    "-----------------------------------------" | Add-Content $Report
    "FEATURE: $Feature" | Add-Content $Report
    "-----------------------------------------" | Add-Content $Report

    $Files = (Get-ChildItem .\lib -Recurse -File -Filter *.dart |
        Where-Object { $_.FullName -match $Feature }).Count

    $Providers = (
        Select-String -Path .\lib\state\providers\*.dart `
        -Pattern $Feature `
        -SimpleMatch `
        -ErrorAction SilentlyContinue
    ).Count

    $Controllers = (
        Select-String -Path .\lib\state\controllers\*.dart `
        -Pattern $Feature *
        -SimpleMatch `
        -E*rorAction SilentlyContinue
    ).C*unt

    $Routes = (
        Selec*-String -Path .\lib\app\*.dart `
 *      -Pattern $Feature `
        *SimpleMatch `
        -ErrorAction*SilentlyContinue
    ).Count

    *Score = 0

    if ($Files -gt 0) {*$Score += 25 }
    if ($Providers *gt 0) { $Score += 25 }
    if ($Co*trollers -gt 0) { $Score += 25 }
 *  if ($Routes -gt 0) { $Score += 2* }

    "Files: $Files" | Add-Cont*nt $Report
    "Providers: $Provid*rs" | Add-Content $Report
    "Con*rollers: $Controllers" | Add-Conte*t $Report
    "Routes: $Routes" | *dd-Content $Report
    "Wiring Sco*e: $Score%" | Add-Content $Report
*

"" | Add-Content $Report
"======*==================================* | Add-Content $Report
"APPVIEW AU*IT" | Add-Content $Report
"=======*================================="*| Add-Content $Report

Select-Stri*g `
    -Path .\lib\state\controll*rs\app_flow_controller.dart `
    *Pattern "AppView|toSmartCoach|toPr*gression|toTrajectoryEngine|toTime*ine|toProfile|toCreator|toConsole"*|
ForEach-Object {
    $_.Line
} |*Add-Content $Report

"" | Add-Cont*nt $Report
"======================*==================" | Add-Content *Report
"NEXUS ACTION HUB" | Add-Co*tent $Report
"====================*====================" | Add-Conten* $Report

Select-String `
    -Pat* .\lib\features\nexus\ui\*.dart `
*   -Pattern "toSmartCoach|toCreato*|toTimeline|toProgression|toTrajec*oryEngine|toProfile|toConsole" `
 *  -ErrorAction SilentlyContinue |
*orEach-Object {
    "$($_.Filename*:$($_.LineNumber): $($_.Line.Trim(*)"
} | Add-Content $Report

"" | A*d-Content $Report
"===============*=========================" | Add-C*ntent $Report
"TRAJECTORY ENGINE" * Add-Content $Report
"============*============================" | Ad*-Content $Report

Select-String `
*   -Path .\lib\**\*.dart `
    -Pa**ern "trajectorySummaryProvider|TrajectoryEngineScreen|trajectoryEngine" `
    -ErrorAction SilentlyContinue |
ForEach-Object {
    "$($_.Path):$($_.LineNumber)"
} | Add-Content $Report

"" | Add-Content $Report
"=========================================" | Add-Content $Report
"ORPHAN SCREENS" | Add-Content $Report
"=========================================" | Add-Content $Report

$Screens = Get-ChildItem .\lib\features -Recurse -Filter *screen.dart

foreach ($Screen in $Screens) {

    $Name = $Screen.Name

    $Refs = (
        Select-String `
            -Path .\lib\**\*.dart `
            -Pattern $Name `
            -SimpleMatch `
            -ErrorAction SilentlyContinue
    ).Count

    if ($Refs -le 1) {
        "POSSIBLE ORPHAN: $($Screen.FullName)" | Add-Content $Report
    }
}

"" | Add-Content $Report
"=========================================" | Add-Content $Report
"FLUTTER ANALYZE" | Add-Content $Report
"=========================================" | Add-Content $Report

flutter analyze | Add-Content $Report

Write-Host ""
Write-Host "Audit complete."
Write-Host "Open: $Report"