param(
    [string]$ProjectRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportsDir = Join-Path $scriptRoot "reports"
$runDir = Join-Path $reportsDir ("performance_stability_{0}" -f $timestamp)
New-Item -Path $runDir -ItemType Directory -Force | Out-Null

$reportFile = Join-Path $runDir "performance_stability_report.md"

function Add-Result {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Details,
        [string]$Evidence = ""
    )
    [pscustomobject]@{
        Name = $Name
        Status = $Status
        Details = $Details
        Evidence = $Evidence
    }
}

Push-Location $ProjectRoot
try {
    $results = @()

    $startupEvidence = Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match 'runtime|startup|hydration|chronospark_runtime|build_release_log'
    }
    if (@($startupEvidence).Count -gt 0) {
        $sample = @($startupEvidence | Select-Object -First 5 | ForEach-Object { $_.Name }) -join ", "
        $results += Add-Result -Name "Startup/hydration evidence artifacts" -Status "PASS" -Details "Found runtime/build evidence files." -Evidence $sample
    }
    else {
        $results += Add-Result -Name "Startup/hydration evidence artifacts" -Status "FAIL" -Details "No startup/hydration evidence files found." -Evidence "Expected runtime/build logs at repo root."
    }

    $lazyTargets = @(
        "lib\\features\\logs\\ui\\logs_screen.dart",
        "lib\\features\\tasks\\ui\\task_screen.dart",
        "lib\\features\\timeline\\ui\\timeline_screen.dart"
    )
    $lazyHitCount = 0
    $lazyEvidence = @()
    foreach ($rel in $lazyTargets) {
        $abs = Join-Path $ProjectRoot $rel
        if (Test-Path $abs) {
            $hits = Select-String -Path $abs -Pattern "ListView\.builder|ListView\.separated|SliverList|ListView\(" -AllMatches -ErrorAction SilentlyContinue
            if (@($hits).Count -gt 0) {
                $lazyHitCount += 1
                $lazyEvidence += "$rel:ok"
            }
            else {
                $lazyEvidence += "$rel:none"
            }
        }
        else {
            $lazyEvidence += "$rel:missing"
        }
    }
    if ($lazyHitCount -ge 2) {
        $results += Add-Result -Name "Lazy list rendering signals" -Status "PASS" -Details "Lazy/list constructs detected in critical list screens." -Evidence ($lazyEvidence -join "; ")
    }
    else {
        $results += Add-Result -Name "Lazy list rendering signals" -Status "FAIL" -Details "Insufficient lazy rendering signals in critical list screens." -Evidence ($lazyEvidence -join "; ")
    }

    $allDart = Get-ChildItem "lib" -Recurse -File -Filter "*.dart" -ErrorAction SilentlyContinue
    $syncIoHits = Select-String -Path $allDart.FullName -Pattern "readAsStringSync|writeAsStringSync|readAsBytesSync|writeAsBytesSync|sleep\(" -AllMatches -ErrorAction SilentlyContinue
    if (@($syncIoHits).Count -eq 0) {
        $results += Add-Result -Name "No obvious sync I/O on UI path" -Status "PASS" -Details "No high-risk sync I/O patterns detected in lib." 
    }
    else {
        $sample = @($syncIoHits | Select-Object -First 5 | ForEach-Object { "{0}:{1}" -f $_.Path.Replace($ProjectRoot + "\\", ""), $_.LineNumber }) -join "; "
        $results += Add-Result -Name "No obvious sync I/O on UI path" -Status "FAIL" -Details "Potential sync I/O patterns detected." -Evidence $sample
    }

    $broadWatchHits = Select-String -Path $allDart.FullName -Pattern "ref\.watch\(appStateProvider\)|ref\.watch\(.*Provider\)" -AllMatches -ErrorAction SilentlyContinue
    $broadCount = @($broadWatchHits).Count
    if ($broadCount -gt 0) {
        $results += Add-Result -Name "Provider watch visibility" -Status "PASS" -Details "Provider watch calls detected; reviewable for rebuild scope." -Evidence "Total watch hits: $broadCount"
    }
    else {
        $results += Add-Result -Name "Provider watch visibility" -Status "FAIL" -Details "No provider watch signals detected; audit script cannot assess rebuild risk." 
    }

    $offlineHits = Select-String -Path $allDart.FullName -Pattern "connectivity_plus|internet_connection_checker|offline|no connection|ConnectionStatus" -AllMatches -ErrorAction SilentlyContinue
    if (@($offlineHits).Count -gt 0) {
        $results += Add-Result -Name "Offline-mode handling signals" -Status "PASS" -Details "Connectivity/offline handling references found." -Evidence ("Hits: " + @($offlineHits).Count)
    }
    else {
        $results += Add-Result -Name "Offline-mode handling signals" -Status "FAIL" -Details "No clear offline handling signals found in lib code." 
    }

    $crashHits = Select-String -Path $allDart.FullName -Pattern "Crashlytics|firebase_crashlytics|recordError|FlutterError\.onError" -AllMatches -ErrorAction SilentlyContinue
    if (@($crashHits).Count -gt 0) {
        $results += Add-Result -Name "Crash reporting readiness signals" -Status "PASS" -Details "Crash reporting references detected." -Evidence ("Hits: " + @($crashHits).Count)
    }
    else {
        $results += Add-Result -Name "Crash reporting readiness signals" -Status "FAIL" -Details "No crash reporting references detected in lib code." 
    }

    $releaseArtifacts = @()
    if (Test-Path (Join-Path $ProjectRoot "artifacts")) {
        $releaseArtifacts += Get-ChildItem (Join-Path $ProjectRoot "artifacts") -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @(".aab", ".apk") }
    }
    if (Test-Path (Join-Path $ProjectRoot "build_release_log.txt")) {
        $releaseArtifacts += Get-Item (Join-Path $ProjectRoot "build_release_log.txt")
    }

    if (@($releaseArtifacts).Count -gt 0) {
        $sample = @($releaseArtifacts | Select-Object -First 5 | ForEach-Object { $_.FullName.Replace($ProjectRoot + "\\", "") }) -join ", "
        $results += Add-Result -Name "Release-mode test evidence" -Status "PASS" -Details "Release artifact/log evidence found." -Evidence $sample
    }
    else {
        $results += Add-Result -Name "Release-mode test evidence" -Status "FAIL" -Details "No release artifact/log evidence found." 
    }

    $bgPath = Join-Path $ProjectRoot "lib\\ui\\layout\\animated_system_background.dart"
    if (Test-Path $bgPath) {
        $bgText = Get-Content $bgPath -Raw
        if ($bgText -match "TickerMode|WidgetsBindingObserver|AppLifecycleState|Visibility") {
            $results += Add-Result -Name "Animated background offscreen/lifecycle signals" -Status "PASS" -Details "Found lifecycle/offscreen control signals for animated backgrounds." -Evidence "lib/ui/layout/animated_system_background.dart"
        }
        else {
            $results += Add-Result -Name "Animated background offscreen/lifecycle signals" -Status "FAIL" -Details "No clear lifecycle/offscreen control signals found for animated backgrounds." -Evidence "lib/ui/layout/animated_system_background.dart"
        }
    }
    else {
        $results += Add-Result -Name "Animated background offscreen/lifecycle signals" -Status "FAIL" -Details "Animated background layout file missing." -Evidence "lib/ui/layout/animated_system_background.dart"
    }

    $siHits = Select-String -Path $allDart.FullName -Pattern "timeout|fallback|safe|graceful|try\s*\{|catch\s*\(" -AllMatches -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -match "si|insight|coach|pipeline"
    }
    if (@($siHits).Count -gt 0) {
        $results += Add-Result -Name "SI recompute safety/fallback signals" -Status "PASS" -Details "SI-related fallback/safety patterns detected." -Evidence ("Hits: " + @($siHits).Count)
    }
    else {
        $results += Add-Result -Name "SI recompute safety/fallback signals" -Status "FAIL" -Details "No clear SI fallback/safety signals detected by heuristic." 
    }

    $failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
    $passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count

    $lines = @()
    $lines += "# Performance + Stability Automated Audit"
    $lines += ""
    $lines += "- Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
    $lines += "- Project root: $ProjectRoot"
    $lines += "- Passed: $passCount"
    $lines += "- Failed: $failCount"
    $lines += ""
    $lines += "| Check | Status | Details | Evidence |"
    $lines += "|---|---|---|---|"

    foreach ($r in $results) {
        $details = ($r.Details -replace "\|", "\\|")
        $evidence = ($r.Evidence -replace "\|", "\\|")
        $lines += "| $($r.Name) | $($r.Status) | $details | $evidence |"
    }

    $lines += ""
    if ($failCount -eq 0) {
        $lines += "Overall result: PASS"
    }
    else {
        $lines += "Overall result: FAIL"
    }

    $lines | Set-Content -Path $reportFile

    Write-Host "Performance/stability audit complete."
    Write-Host ("Report: {0}" -f $reportFile)

    if ($failCount -gt 0) {
        exit 1
    }
    exit 0
}
finally {
    Pop-Location
}
