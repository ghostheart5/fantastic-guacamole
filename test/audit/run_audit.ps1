param(
    [string]$ProjectRoot = "",
    [switch]$NoWindowsBuild,
    [switch]$NoAndroidReleaseBuild,
    [switch]$NoPermissionsPrivacyAudit,
    [switch]$NoVisualDesignAudit,
    [switch]$NoPerformanceStabilityAudit,
    [switch]$NoSubscriptionPaywallAudit,
    [switch]$NoAccessibilityAudit,
    [switch]$NoSecurityTrustAudit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-SafeName {
    param([string]$Value)
    return (($Value -replace "[^a-zA-Z0-9]+", "_").Trim("_"))
}

function Invoke-AuditCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$LogDirectory
    )

    $safe = New-SafeName -Value $Name
    $logFile = Join-Path $LogDirectory ("{0}.log" -f $safe)
    $start = Get-Date
    $status = "PASS"
    $exitCode = 0

    try {
        $cmdLine = "$Command 2>&1"
        $output = & cmd.exe /d /c $cmdLine
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }
        if ($exitCode -ne 0) {
            $status = "FAIL"
        }
    }
    catch {
        $output = @("Exception: $($_.Exception.Message)")
        $status = "FAIL"
        $exitCode = 1
    }

    $end = Get-Date
    $duration = [Math]::Round(($end - $start).TotalSeconds, 2)

    @(
        "Check: $Name",
        "Command: $Command",
        "Started: $($start.ToString("s"))",
        "Ended: $($end.ToString("s"))",
        "DurationSeconds: $duration",
        "ExitCode: $exitCode",
        "Status: $status",
        "",
        "--- Output ---",
        ($output -join [Environment]::NewLine)
    ) | Set-Content -Path $logFile

    return [pscustomobject]@{
        Name = $Name
        Command = $Command
        Status = $status
        ExitCode = $exitCode
        DurationSeconds = $duration
        LogFile = $logFile
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportsDir = Join-Path $scriptRoot "reports"
$runDir = Join-Path $reportsDir ("run_{0}" -f $timestamp)
$logDir = Join-Path $runDir "logs"

New-Item -Path $runDir -ItemType Directory -Force | Out-Null
New-Item -Path $logDir -ItemType Directory -Force | Out-Null

Push-Location $ProjectRoot

try {
    $checks = @(
        @{ Name = "Git status"; Command = "git status --short" },
        @{ Name = "Current branch"; Command = "git branch --show-current" },
        @{ Name = "Last commit"; Command = "git rev-parse --short HEAD" },
        @{ Name = "Flutter version"; Command = "flutter --version" },
        @{ Name = "Dart version"; Command = "dart --version" },
        @{ Name = "Flutter doctor"; Command = "flutter doctor -v" },
        @{ Name = "Connected devices"; Command = "flutter devices" },
        @{ Name = "Pub get"; Command = "flutter pub get" },
        @{ Name = "Analyze"; Command = "flutter analyze" },
        @{ Name = "Test"; Command = "flutter test" }
    )

    if (-not $NoWindowsBuild) {
        $checks += @{ Name = "Windows debug build"; Command = "flutter build windows --debug" }
    }

    if (-not $NoAndroidReleaseBuild) {
        $checks += @{ Name = "Android appbundle release build"; Command = "flutter build appbundle --release" }
    }

    if (-not $NoPermissionsPrivacyAudit) {
        $permissionAuditScript = Join-Path $scriptRoot "run_permissions_privacy_audit.ps1"
        $checks += @{ Name = "Android permissions privacy audit"; Command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$permissionAuditScript`" -ProjectRoot `"$ProjectRoot`"" }
    }

    if (-not $NoVisualDesignAudit) {
        $visualAuditScript = Join-Path $scriptRoot "run_visual_design_premium_audit.ps1"
        $checks += @{ Name = "Visual design premium feel audit"; Command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$visualAuditScript`" -ProjectRoot `"$ProjectRoot`"" }
    }

    if (-not $NoPerformanceStabilityAudit) {
        $perfAuditScript = Join-Path $scriptRoot "run_performance_stability_audit.ps1"
        $checks += @{ Name = "Performance stability audit"; Command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$perfAuditScript`" -ProjectRoot `"$ProjectRoot`"" }
    }

    if (-not $NoSubscriptionPaywallAudit) {
        $subscriptionAuditScript = Join-Path $scriptRoot "run_subscription_paywall_audit.ps1"
        $checks += @{ Name = "Subscription paywall audit"; Command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$subscriptionAuditScript`" -ProjectRoot `"$ProjectRoot`"" }
    }

    if (-not $NoAccessibilityAudit) {
        $accessibilityAuditScript = Join-Path $scriptRoot "run_accessibility_real_user_audit.ps1"
        $checks += @{ Name = "Accessibility real user audit"; Command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$accessibilityAuditScript`" -ProjectRoot `"$ProjectRoot`"" }
    }

    if (-not $NoSecurityTrustAudit) {
        $securityTrustAuditScript = Join-Path $scriptRoot "run_security_trust_audit.ps1"
        $checks += @{ Name = "Security trust audit"; Command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$securityTrustAuditScript`" -ProjectRoot `"$ProjectRoot`"" }
    }

    $results = @()
    foreach ($check in $checks) {
        Write-Host ("Running: {0}" -f $check.Name)
        $result = Invoke-AuditCheck -Name $check.Name -Command $check.Command -LogDirectory $logDir
        $results += $result
        Write-Host ("  -> {0} (exit {1})" -f $result.Status, $result.ExitCode)
    }

    $passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count
    $failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count

    $reportFile = Join-Path $runDir "audit_report.md"

    $lines = @()
    $lines += "# ChronoSpark Automated Audit Report"
    $lines += ""
    $lines += "- Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
    $lines += "- Project root: $ProjectRoot"
    $lines += "- Checks run: $($results.Count)"
    $lines += "- Passed: $passCount"
    $lines += "- Failed: $failCount"
    $lines += ""
    $lines += "| Check | Status | Exit Code | Duration (s) | Log |"
    $lines += "|---|---|---:|---:|---|"

    foreach ($r in $results) {
        $relLog = Resolve-Path -Relative $r.LogFile
        $lines += "| $($r.Name) | $($r.Status) | $($r.ExitCode) | $($r.DurationSeconds) | $relLog |"
    }

    $lines += ""
    if ($failCount -eq 0) {
        $lines += "Overall result: PASS"
    }
    else {
        $lines += "Overall result: FAIL"
    }

    $lines | Set-Content -Path $reportFile

    Write-Host ""
    Write-Host "Audit complete."
    Write-Host ("Report: {0}" -f $reportFile)
    Write-Host ("Logs:   {0}" -f $logDir)

    if ($failCount -gt 0) {
        exit 1
    }

    exit 0
}
finally {
    Pop-Location
}
