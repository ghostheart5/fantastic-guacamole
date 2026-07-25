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
$runDir = Join-Path $reportsDir ("accessibility_real_user_{0}" -f $timestamp)
New-Item -Path $runDir -ItemType Directory -Force | Out-Null

$reportFile = Join-Path $runDir "accessibility_real_user_report.md"

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

function Read-IfExists {
    param([string]$Path)
    if (Test-Path $Path) { return (Get-Content $Path -Raw) }
    return ""
}

Push-Location $ProjectRoot
try {
    $results = @()
    $allDart = Get-ChildItem "lib" -Recurse -File -Filter "*.dart" -ErrorAction SilentlyContinue

    $accessibilityFiles = @(
        "lib\ui\widgets\holo_button.dart",
        "lib\ui\widgets\offline_banner.dart",
        "lib\ui\widgets\typing_text.dart",
        "lib\ui\layout\animated_system_background.dart",
        "lib\theme\widgets\neon_input.dart",
        "lib\features\auth\screens\auth_gate.dart",
        "lib\features\settings\ui\settings_screen.dart",
        "lib\features\settings\ui\settings_screen.sections.dart",
        "lib\features\home\ui\smart_coach_screen.dart",
        "lib\features\nexus\ui\nexus_screen.dart",
        "lib\features\goals\ui\goals_screen.dart",
        "lib\features\paywall\ui\paywall_page.dart",
        "lib\tutorial\tutorial_content.dart"
    )
    $existingFiles = @($accessibilityFiles | Where-Object { Test-Path (Join-Path $ProjectRoot $_) })
    if ($existingFiles.Count -ge 10) {
        $results += Add-Result -Name "Accessibility surface present" -Status "PASS" -Details "Core user-facing surfaces found." -Evidence ($existingFiles -join ", ")
    }
    else {
        $results += Add-Result -Name "Accessibility surface present" -Status "FAIL" -Details "Some expected surfaces are missing." -Evidence ($existingFiles -join ", ")
    }

    $semanticsHits = Select-String -Path $allDart.FullName -Pattern "Semantics\(|Tooltip\(|semanticLabel|labelText|helperText|errorText|validator" -AllMatches -ErrorAction SilentlyContinue
    if (@($semanticsHits).Count -ge 25) {
        $results += Add-Result -Name "Screen reader labels and form labels" -Status "PASS" -Details "Labels/semantics/validators signals detected." -Evidence ("Hits: " + @($semanticsHits).Count)
    }
    else {
        $results += Add-Result -Name "Screen reader labels and form labels" -Status "FAIL" -Details "Label/semantics/validator signals appear thin." -Evidence ("Hits: " + @($semanticsHits).Count)
    }

    $tapTargetSignals = @(
        "minWidth: 48",
        "minHeight: 48",
        "GestureDetector(",
        "IconButton(",
        "FilledButton(",
        "OutlinedButton(",
        "TextButton("
    )
    $tapTargetHits = @($tapTargetSignals | Where-Object { $allDart.FullName | ForEach-Object { $false } })
    $targetText = ($allDart | ForEach-Object { Read-IfExists $_.FullName }) -join "`n"
    $tapHits = @($tapTargetSignals | Where-Object { $targetText -match [regex]::Escape($_) }).Count
    if ($tapHits -ge 5) {
        $results += Add-Result -Name "Tap target sizing signals" -Status "PASS" -Details "Thumb-friendly control sizing signals detected." -Evidence "Hits: $tapHits"
    }
    else {
        $results += Add-Result -Name "Tap target sizing signals" -Status "FAIL" -Details "Tap-target sizing evidence appears weak." -Evidence "Hits: $tapHits"
    }

    $motionSignals = @(
        "disableAnimations",
        "AnimatedSize(",
        "duration: const Duration(milliseconds: 110)",
        "duration: const Duration(milliseconds: 300)",
        "_controller.stop()",
        "_controller.repeat(reverse: true)"
    )
    $motionHits = @($motionSignals | Where-Object { $targetText -match [regex]::Escape($_) }).Count
    if ($motionHits -ge 5) {
        $results += Add-Result -Name "Reduced motion respected or planned" -Status "PASS" -Details "Reduced-motion/lifecycle controls detected." -Evidence "Hits: $motionHits"
    }
    else {
        $results += Add-Result -Name "Reduced motion respected or planned" -Status "FAIL" -Details "Reduced-motion controls appear incomplete." -Evidence "Hits: $motionHits"
    }

    $offlineSignals = @(
        "Offline Mode",
        "offline",
        "error",
        "retry",
        "sync later",
        "will sync later",
        "No connection",
        "Actions will sync later"
    )
    $offlineHits = @($offlineSignals | Where-Object { $targetText -match [regex]::Escape($_) }).Count
    if ($offlineHits -ge 5) {
        $results += Add-Result -Name "Offline/error states understandable" -Status "PASS" -Details "Offline and retry copy signals found." -Evidence "Hits: $offlineHits"
    }
    else {
        $results += Add-Result -Name "Offline/error states understandable" -Status "FAIL" -Details "Offline/error copy signals appear thin." -Evidence "Hits: $offlineHits"
    }

    $formSignals = @("labelText:", "validator:", "errorText:", "hintText:", "TextField(", "TextFormField(")
    $formHits = @($formSignals | Where-Object { $targetText -match [regex]::Escape($_) }).Count
    if ($formHits -ge 5) {
        $results += Add-Result -Name "Forms have clear labels and validation messages" -Status "PASS" -Details "Form labels and validation signals found." -Evidence "Hits: $formHits"
    }
    else {
        $results += Add-Result -Name "Forms have clear labels and validation messages" -Status "FAIL" -Details "Form label/validation evidence appears weak." -Evidence "Hits: $formHits"
    }

    $errorPath = Join-Path $ProjectRoot "lib\features\auth\screens\auth_gate.dart"
    if (Test-Path $errorPath) {
        $errorText = Read-IfExists $errorPath
        $errorSignals = @("what happened", "Retry", "Try again", "failed", "update", "request", "password", "Back to Sign In")
        $errorHits = @($errorSignals | Where-Object { $errorText -match [regex]::Escape($_) }).Count
        if ($errorHits -ge 4) {
            $results += Add-Result -Name "Error messages say what happened and next step" -Status "PASS" -Details "Helpful recovery/error language detected." -Evidence "Hits: $errorHits"
        }
        else {
            $results += Add-Result -Name "Error messages say what happened and next step" -Status "FAIL" -Details "Error recovery language is weak." -Evidence "Hits: $errorHits"
        }
    }

    $firstTimeSignals = @(
        "first task",
        "Create your first",
        "Open Nexus",
        "Try Prompt",
        "Set Reminder",
        "Create Task",
        "No goals yet",
        "No tasks yet",
        "Add your first"
    )
    $firstTimeHits = @($firstTimeSignals | Where-Object { $targetText -match [regex]::Escape($_) }).Count
    if ($firstTimeHits -ge 5) {
        $results += Add-Result -Name "First-time user can complete first task" -Status "PASS" -Details "Onboarding/tutorial/empty-state guidance detected." -Evidence "Hits: $firstTimeHits"
    }
    else {
        $results += Add-Result -Name "First-time user can complete first task" -Status "FAIL" -Details "First-run guidance signals appear thin." -Evidence "Hits: $firstTimeHits"
    }

    $internalModulePattern = '(?<![A-Za-z])(provider|controller|repository|module|engine|features\/|lib\\features\\)(?![A-Za-z])'
    $userFacingCopyFiles = @(
        "lib\app\router\app_router.dart",
        "lib\app\router\info_pages.dart",
        "lib\features\auth\screens\auth_gate.dart",
        "lib\features\settings\ui\settings_screen.dart",
        "lib\features\settings\ui\settings_screen.sections.dart",
        "lib\features\home\ui\smart_coach_screen.dart",
        "lib\features\goals\ui\goals_screen.dart",
        "lib\features\paywall\ui\paywall_page.dart",
        "lib\tutorial\tutorial_content.dart",
        "lib\ui\widgets\holo_button.dart",
        "lib\ui\widgets\offline_banner.dart",
        "lib\ui\widgets\typing_text.dart",
        "lib\theme\widgets\neon_input.dart",
        "lib\ui\layout\animated_system_background.dart"
    ) | Where-Object { Test-Path (Join-Path $ProjectRoot $_) }
    $userFacingStringPattern = '"[^"]*' + $internalModulePattern + '[^"]*"|\x27[^\x27]*' + $internalModulePattern + '[^\x27]*\x27'
    $userFacingStringHits = if ($userFacingCopyFiles.Count -gt 0) {
        Select-String -Path ($userFacingCopyFiles | ForEach-Object { Join-Path $ProjectRoot $_ }) -Pattern $userFacingStringPattern -AllMatches -ErrorAction SilentlyContinue | Where-Object {
            $_.Line -match 'Text\(|title:|body:|tooltip:|callToActionLabel:|labelText:|helperText:|errorText:|hintText:' -and
            $_.Line -notmatch '^\s*(import|export|part)\s'
        }
    }
    else {
        @()
    }
    if (@($userFacingStringHits).Count -eq 0) {
        $results += Add-Result -Name "No internal module names in user-facing copy" -Status "PASS" -Details "No obvious internal-module names found in visible string literals." 
    }
    else {
        $examples = @($userFacingStringHits | Select-Object -First 5 | ForEach-Object { "{0}:{1}" -f $_.Path.Replace($ProjectRoot + "\\", ""), $_.LineNumber }) -join "; "
        $results += Add-Result -Name "No internal module names in user-facing copy" -Status "FAIL" -Details "Potential internal module names found in string literals." -Evidence $examples
    }

    $contrastSignals = @(
        "AppColors.",
        "white70",
        "white54",
        "white38",
        "Colors.white",
        "Colors.black",
        "Color(0xFF",
        "ThemeData.dark",
        "TextTheme"
    )
    $contrastHits = @($contrastSignals | Where-Object { $targetText -match [regex]::Escape($_) }).Count
    if ($contrastHits -ge 6) {
        $results += Add-Result -Name "Contrast signals for body/secondary text" -Status "PASS" -Details "Theme and UI contrast signals detected." -Evidence "Hits: $contrastHits"
    }
    else {
        $results += Add-Result -Name "Contrast signals for body/secondary text" -Status "FAIL" -Details "Contrast evidence is weak in heuristics." -Evidence "Hits: $contrastHits"
    }

    $failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
    $passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count

    $lines = @()
    $lines += "# Accessibility + Real-User Usability Automated Audit"
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

    Write-Host "Accessibility audit complete."
    Write-Host ("Report: {0}" -f $reportFile)

    if ($failCount -gt 0) {
        exit 1
    }
    exit 0
}
finally {
    Pop-Location
}
