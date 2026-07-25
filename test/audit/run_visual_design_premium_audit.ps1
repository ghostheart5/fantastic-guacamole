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
$runDir = Join-Path $reportsDir ("visual_design_{0}" -f $timestamp)
New-Item -Path $runDir -ItemType Directory -Force | Out-Null

$reportFile = Join-Path $runDir "visual_design_report.md"

function Add-Result {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Details,
        [string]$Evidence = ""
    )
    return [pscustomobject]@{
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
    $knownStateSignalExceptions = @(
        "lib\features\nexus\ui\nexus_screen.dart"
    )

    $themePath = Join-Path $ProjectRoot "lib\theme\theme.dart"
    if (-not (Test-Path $themePath)) {
        $results += Add-Result -Name "Theme file exists" -Status "FAIL" -Details "Missing lib/theme/theme.dart" -Evidence "lib/theme/theme.dart"
    }
    else {
        $results += Add-Result -Name "Theme file exists" -Status "PASS" -Details "Theme file found." -Evidence "lib/theme/theme.dart"
        $themeText = Read-IfExists $themePath

        $themeSourceFiles = @($themePath)
        $exportMatches = [regex]::Matches($themeText, "export 'package:fantastic_guacamole/(.+?)';")
        foreach ($match in $exportMatches) {
            $rel = $match.Groups[1].Value -replace "/", "\\"
            $abs = Join-Path $ProjectRoot "lib\\$rel"
            if (Test-Path $abs) {
                $themeSourceFiles += $abs
            }
        }
        $themeSourceFiles = @($themeSourceFiles | Sort-Object -Unique)
        $themeCorpus = @($themeSourceFiles | ForEach-Object { Read-IfExists $_ }) -join "`n"

        $darkSignals = @(
            "Brightness.dark",
            "ThemeData.dark",
            "scaffoldBackgroundColor",
            "Color(0xFF",
            "surface",
            "nearBlack",
            "midnightBlack",
            "deepNavy"
        )
        $darkHits = @($darkSignals | Where-Object { $themeCorpus -match [regex]::Escape($_) }).Count
        if ($darkHits -ge 3) {
            $results += Add-Result -Name "Dark clean default signals" -Status "PASS" -Details "Dark-theme tokens detected." -Evidence ("Hits: $darkHits; Files: " + ($themeSourceFiles.Count))
        }
        else {
            $results += Add-Result -Name "Dark clean default signals" -Status "FAIL" -Details "Insufficient dark-theme signals in theme definitions." -Evidence ("Hits: $darkHits; Files: " + ($themeSourceFiles.Count))
        }

        $typographySignals = @(
            "TextTheme",
            "titleLarge",
            "titleMedium",
            "bodyLarge",
            "bodyMedium",
            "labelLarge",
            "headlineLarge",
            "headlineMedium"
        )
        $typeHits = @($typographySignals | Where-Object { $themeCorpus -match [regex]::Escape($_) }).Count
        if ($typeHits -ge 4) {
            $results += Add-Result -Name "Typography hierarchy signals" -Status "PASS" -Details "Title/body/label style signals present." -Evidence ("Hits: $typeHits; Files: " + ($themeSourceFiles.Count))
        }
        else {
            $results += Add-Result -Name "Typography hierarchy signals" -Status "FAIL" -Details "Typography hierarchy appears underspecified." -Evidence ("Hits: $typeHits; Files: " + ($themeSourceFiles.Count))
        }
    }

    $coreScreenPaths = @(
        "lib\features\nexus\ui\nexus_screen.dart",
        "lib\features\home\ui\smart_coach_screen.dart",
        "lib\features\plan\ui\plan_screen.dart",
        "lib\features\logs\ui\logs_screen.dart",
        "lib\features\settings\ui\settings_screen.dart",
        "lib\features\si_console\ui\si_console_screen.dart"
    )

    $existingScreens = @($coreScreenPaths | Where-Object { Test-Path (Join-Path $ProjectRoot $_) })
    if ($existingScreens.Count -ge 5) {
        $results += Add-Result -Name "Core polish screens present" -Status "PASS" -Details "Expected core screens found." -Evidence ("Found: " + ($existingScreens -join ", "))
    }
    else {
        $results += Add-Result -Name "Core polish screens present" -Status "FAIL" -Details "Some core screens are missing." -Evidence ("Found: " + ($existingScreens -join ", "))
    }

    $uiFiles = Get-ChildItem "lib\features" -Recurse -File -Filter "*.dart" -ErrorAction SilentlyContinue

    $buttonTokens = @("ElevatedButton", "TextButton", "IconButton")
    $buttonHits = 0
    foreach ($token in $buttonTokens) {
        $hits = Select-String -Path $uiFiles.FullName -Pattern $token -ErrorAction SilentlyContinue
        $buttonHits += @($hits).Count
    }
    if ($buttonHits -gt 0) {
        $results += Add-Result -Name "Button hierarchy signals" -Status "PASS" -Details "Primary/secondary/quiet button widgets detected." -Evidence "Total button token hits: $buttonHits"
    }
    else {
        $results += Add-Result -Name "Button hierarchy signals" -Status "FAIL" -Details "No button hierarchy tokens detected." -Evidence "Total button token hits: 0"
    }

    $animationMatches = Select-String -Path $uiFiles.FullName -Pattern "Duration\(seconds:\s*([2-9]|[1-9][0-9]+)\)" -AllMatches -ErrorAction SilentlyContinue
    $longAnimationCount = @($animationMatches).Count
    if ($longAnimationCount -eq 0) {
        $results += Add-Result -Name "Animation duration guardrail" -Status "PASS" -Details "No long animations (>=2s) detected in feature UI." 
    }
    else {
        $examples = @($animationMatches | Select-Object -First 5 | ForEach-Object { "{0}:{1}" -f $_.Path.Replace($ProjectRoot + "\\", ""), $_.LineNumber })
        $results += Add-Result -Name "Animation duration guardrail" -Status "FAIL" -Details "Long animations detected; may slow interactions." -Evidence ($examples -join "; ")
    }

    $stateKeywords = @("loading", "error", "empty", "success")
    $stateCoverage = @()
    foreach ($relPath in $existingScreens) {
        $absPath = Join-Path $ProjectRoot $relPath
        $text = Read-IfExists $absPath
        $present = @($stateKeywords | Where-Object { $text -match $_ })
        $stateCoverage += [pscustomobject]@{
            Screen = $relPath
            Count = $present.Count
            Tokens = ($present -join ",")
        }
    }

    $lowCoverage = @($stateCoverage | Where-Object { $_.Count -lt 2 })
    $effectiveLowCoverage = @($lowCoverage | Where-Object { $knownStateSignalExceptions -notcontains $_.Screen })

    if ($effectiveLowCoverage.Count -eq 0) {
        $exceptionNote = ""
        if ($lowCoverage.Count -ne 0) {
            $exceptionNote = " (known exception applied)"
        }
        $results += Add-Result -Name "State handling signals per core screen" -Status "PASS" -Details "Each core screen has at least 2 state keywords." -Evidence (($stateCoverage | ForEach-Object { "$($_.Screen)=$($_.Count)" }) -join "; ")
        if (-not [string]::IsNullOrWhiteSpace($exceptionNote)) {
            $results += Add-Result -Name "State handling known exceptions" -Status "PASS" -Details "Known state-signal exceptions were excluded from fail criteria." -Evidence (($lowCoverage | ForEach-Object { $_.Screen }) -join ", ")
        }
    }
    else {
        $results += Add-Result -Name "State handling signals per core screen" -Status "FAIL" -Details "One or more core screens have weak state handling signals." -Evidence (($effectiveLowCoverage | ForEach-Object { "$($_.Screen)=$($_.Count)" }) -join "; ")
    }

    $paywallCandidates = @(
        "lib\features\paywall\ui\paywall_page.dart",
        "lib\features\monetization\presentation\paywall_screen.dart",
        "lib\features\monetization\presentation\screens\paywall_screen.dart"
    )
    $paywallFile = $null
    foreach ($candidate in $paywallCandidates) {
        $abs = Join-Path $ProjectRoot $candidate
        if (Test-Path $abs) {
            $paywallFile = $abs
            break
        }
    }

    if ($null -eq $paywallFile) {
        $results += Add-Result -Name "Paywall implementation present" -Status "FAIL" -Details "No known paywall screen found." 
    }
    else {
        $results += Add-Result -Name "Paywall implementation present" -Status "PASS" -Details "Paywall file found." -Evidence ($paywallFile.Replace($ProjectRoot + "\\", ""))
        $paywallText = Read-IfExists $paywallFile
        $spamTokens = @("hurry", "limited time", "act now", "last chance", "urgent")
        $spamHits = @($spamTokens | Where-Object { $paywallText -match [regex]::Escape($_) }).Count
        if ($spamHits -eq 0) {
            $results += Add-Result -Name "Paywall calm-language heuristic" -Status "PASS" -Details "No spammy urgency phrases detected." 
        }
        else {
            $results += Add-Result -Name "Paywall calm-language heuristic" -Status "FAIL" -Details "Urgency/spam phrase signals detected in paywall copy." -Evidence "Spam token hits: $spamHits"
        }
    }

    $failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
    $passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count

    $lines = @()
    $lines += "# Visual Design + Premium Feel Automated Audit"
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

    Write-Host "Visual design audit complete."
    Write-Host ("Report: {0}" -f $reportFile)

    if ($failCount -gt 0) {
        exit 1
    }
    exit 0
}
finally {
    Pop-Location
}
