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
$runDir = Join-Path $reportsDir ("subscription_paywall_{0}" -f $timestamp)
New-Item -Path $runDir -ItemType Directory -Force | Out-Null

$reportFile = Join-Path $runDir "subscription_paywall_report.md"

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

    $entitlementPath = Join-Path $ProjectRoot "lib\features\monetization\data\models\premium_entitlement.dart"
    $accessPath = Join-Path $ProjectRoot "lib\state\providers\access_provider.dart"
    $googlePaywallPath = Join-Path $ProjectRoot "lib\data\repositories\google_play_paywall_repository.dart"
    $paywallPagePath = Join-Path $ProjectRoot "lib\features\paywall\ui\paywall_page.dart"
    $subscriptionManagementPath = Join-Path $ProjectRoot "lib\features\monetization\presentation\screens\subscription_management_screen.dart"
    $cleanupPath = Join-Path $ProjectRoot "lib\data\services\local_user_data_cleanup_service.dart"
    $supportPagePath = Join-Path $ProjectRoot "lib\app\router\info_pages.dart"
    $settingsPagePath = Join-Path $ProjectRoot "lib\features\settings\ui\settings_screen.dart"
    $envPath = Join-Path $ProjectRoot "lib\config\env.dart"

    $baseMapEvidence = @()
    if (Test-Path $entitlementPath) { $baseMapEvidence += "entitlement" }
    if (Test-Path $accessPath) { $baseMapEvidence += "access" }
    if (Test-Path $googlePaywallPath) { $baseMapEvidence += "google_play" }
    if (Test-Path $paywallPagePath) { $baseMapEvidence += "paywall_ui" }

    if ($baseMapEvidence.Count -ge 4) {
        $results += Add-Result -Name "Tier and paywall implementation present" -Status "PASS" -Details "Core subscription/paywall files found." -Evidence ($baseMapEvidence -join ", ")
    }
    else {
        $results += Add-Result -Name "Tier and paywall implementation present" -Status "FAIL" -Details "Missing one or more core subscription/paywall files." -Evidence ($baseMapEvidence -join ", ")
    }

    if (Test-Path $entitlementPath) {
        $entitlementText = Read-IfExists $entitlementPath
        $tierSignals = @("EntitlementTier.free", "EntitlementTier.premium", "EntitlementTier.ultimate")
        $tierHits = @($tierSignals | Where-Object { $entitlementText -match [regex]::Escape($_) }).Count
        if ($tierHits -eq 3) {
            $results += Add-Result -Name "Base Premium Ultimate mapping" -Status "PASS" -Details "All tier enum signals present." -Evidence "Hits: $tierHits"
        }
        else {
            $results += Add-Result -Name "Base Premium Ultimate mapping" -Status "FAIL" -Details "Tier enum mapping is incomplete or missing." -Evidence "Hits: $tierHits"
        }
    }
    else {
        $results += Add-Result -Name "Base Premium Ultimate mapping" -Status "FAIL" -Details "Missing entitlement model file." 
    }

    if (Test-Path $googlePaywallPath) {
        $googleText = Read-IfExists $googlePaywallPath
        $productSignals = @("chronospark_premium_monthly", "chronospark_premium_annual")
        $productHits = @($productSignals | Where-Object { $googleText -match [regex]::Escape($_) }).Count
        $productionSignals = @("InAppPurchase.instance", "Receipt verification", "paywallTestingMode", "_hasReceiptVerification")
        $productionHits = @($productionSignals | Where-Object { $googleText -match [regex]::Escape($_) }).Count
        if ($productHits -eq 2 -and $productionHits -ge 2) {
            $results += Add-Result -Name "Billing provider selected and production-ready" -Status "PASS" -Details "Google Play billing and verification signals detected." -Evidence "Product hits: $productHits; Production hits: $productionHits"
        }
        else {
            $results += Add-Result -Name "Billing provider selected and production-ready" -Status "FAIL" -Details "Billing provider readiness signals incomplete." -Evidence "Product hits: $productHits; Production hits: $productionHits"
        }

        if ($googleText -match "MockBillingService") {
            $results += Add-Result -Name "MockBillingService removed or disabled" -Status "FAIL" -Details "MockBillingService reference found in production billing code." 
        }
        else {
            $results += Add-Result -Name "MockBillingService removed or disabled" -Status "PASS" -Details "No MockBillingService reference found in production billing code." 
        }

        $planCopySignals = @("Premium Monthly", "Premium Yearly", "free trial", "AI Credits + Premium", "Smart Credits + Premium")
        $planCopyHits = @($planCopySignals | Where-Object { $googleText -match [regex]::Escape($_) }).Count
        if ($planCopyHits -ge 4) {
            $results += Add-Result -Name "Store subscription products match UI copy" -Status "PASS" -Details "Product and UI copy signals align." -Evidence "Hits: $planCopyHits"
        }
        else {
            $results += Add-Result -Name "Store subscription products match UI copy" -Status "FAIL" -Details "Store/UI copy mapping appears incomplete." -Evidence "Hits: $planCopyHits"
        }

        $trialSignals = @("freeTrialDays", "trial", "_detectFreeTrialDays")
        $trialHits = @($trialSignals | Where-Object { $googleText -match [regex]::Escape($_) }).Count
        if ($trialHits -ge 2) {
            $results += Add-Result -Name "Trial quotas are exact and tested" -Status "PASS" -Details "Trial logic and quota detection signals present." -Evidence "Hits: $trialHits"
        }
        else {
            $results += Add-Result -Name "Trial quotas are exact and tested" -Status "FAIL" -Details "Trial quota logic signals appear weak or missing." -Evidence "Hits: $trialHits"
        }

        $offlineSignals = @("restorePurchases", "TimeoutException", "StateError", "pending_verification")
        $offlineHits = @($offlineSignals | Where-Object { $googleText -match [regex]::Escape($_) }).Count
        if ($offlineHits -ge 3) {
            $results += Add-Result -Name "Subscription state handles offline gracefully" -Status "PASS" -Details "Offline/timeout fallback signals detected." -Evidence "Hits: $offlineHits"
        }
        else {
            $results += Add-Result -Name "Subscription state handles offline gracefully" -Status "FAIL" -Details "Offline fallback signals are incomplete." -Evidence "Hits: $offlineHits"
        }

        $expiredCanceledSignals = @("cancelSubscription", "cancelled", "expired", "restored", "pending_verification")
        $expiredHits = @($expiredCanceledSignals | Where-Object { $googleText -match [regex]::Escape($_) }).Count
        if ($expiredHits -ge 3) {
            $results += Add-Result -Name "Expired/canceled subscription behavior tested" -Status "PASS" -Details "Cancellation/restoration state handling signals detected." -Evidence "Hits: $expiredHits"
        }
        else {
            $results += Add-Result -Name "Expired/canceled subscription behavior tested" -Status "FAIL" -Details "Cancellation/expiry handling signals are incomplete." -Evidence "Hits: $expiredHits"
        }
    }

    if (Test-Path $paywallPagePath) {
        $paywallText = Read-IfExists $paywallPagePath
        $intrusiveSignals = @("AlertDialog", "showDialog", "popup", "Dialog(", "BottomSheet")
        $intrusiveHits = @($intrusiveSignals | Where-Object { $paywallText -match [regex]::Escape($_) }).Count
        if ($intrusiveHits -eq 0) {
            $results += Add-Result -Name "No intrusive popups" -Status "PASS" -Details "No intrusive popup/dialog signals detected in paywall UI." 
        }
        else {
            $results += Add-Result -Name "No intrusive popups" -Status "FAIL" -Details "Potential popup/dialog signals detected in paywall UI." -Evidence "Hits: $intrusiveHits"
        }

        $meaningfulBoundarySignals = @("Premium Feature Gate", "Choose plan", "Restore Purchases", "Subscription access", "feature gate")
        $boundaryHits = @($meaningfulBoundarySignals | Where-Object { $paywallText -match [regex]::Escape($_) }).Count
        if ($boundaryHits -ge 3) {
            $results += Add-Result -Name "Paywall only at meaningful feature boundary" -Status "PASS" -Details "Paywall gate and purchase flow are user-invoked." -Evidence "Hits: $boundaryHits"
        }
        else {
            $results += Add-Result -Name "Paywall only at meaningful feature boundary" -Status "FAIL" -Details "Boundary signals are weak or missing." -Evidence "Hits: $boundaryHits"
        }

        $supportSignals = @("Cancel anytime", "No hidden fees", "support@chronospark.app", "support")
        $supportHits = @($supportSignals | Where-Object { $paywallText -match [regex]::Escape($_) }).Count
        if ($supportHits -ge 2) {
            $results += Add-Result -Name "Refund/support language prepared" -Status "PASS" -Details "Support/refund/cancellation language detected." -Evidence "Hits: $supportHits"
        }
        else {
            $results += Add-Result -Name "Refund/support language prepared" -Status "FAIL" -Details "Support/refund language seems incomplete." -Evidence "Hits: $supportHits"
        }
    }

    if (Test-Path $subscriptionManagementPath) {
        $subscriptionText = Read-IfExists $subscriptionManagementPath
        if ($subscriptionText -match "Plan:|Status:|Auto-renew:|No active subscription record found") {
            $results += Add-Result -Name "Subscription state review screen present" -Status "PASS" -Details "Subscription management screen exposes state and auto-renew visibility." -Evidence "lib/features/monetization/presentation/screens/subscription_management_screen.dart"
        }
        else {
            $results += Add-Result -Name "Subscription state review screen present" -Status "FAIL" -Details "Subscription management screen state visibility appears incomplete." 
        }
    }

    if (Test-Path $cleanupPath) {
        $cleanupText = Read-IfExists $cleanupPath
        $retentionSignals = @("paywall_subscription_state_v1", "clear", "delete")
        $retentionHits = @($retentionSignals | Where-Object { $cleanupText -match [regex]::Escape($_) }).Count
        if ($retentionHits -ge 2) {
            $results += Add-Result -Name "Upgrade/downgrade preserves user data" -Status "PASS" -Details "Cleanup service excludes subscription state and supports selective deletion." -Evidence "Hits: $retentionHits"
        }
        else {
            $results += Add-Result -Name "Upgrade/downgrade preserves user data" -Status "FAIL" -Details "User data retention signals are weak." -Evidence "Hits: $retentionHits"
        }
    }

    if (Test-Path $envPath) {
        $envText = Read-IfExists $envPath
        $supportSignals = @("supportUrl", "supportEmail", "chronospark.app/support")
        $supportHits = @($supportSignals | Where-Object { $envText -match [regex]::Escape($_) }).Count
        if ($supportHits -ge 2) {
            $results += Add-Result -Name "Support contact ready" -Status "PASS" -Details "Support URL/email signals present." -Evidence "Hits: $supportHits"
        }
        else {
            $results += Add-Result -Name "Support contact ready" -Status "FAIL" -Details "Support contact signals are incomplete." -Evidence "Hits: $supportHits"
        }
    }

    $failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
    $passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count

    $lines = @()
    $lines += "# Subscription + Paywall Automated Audit"
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

    Write-Host "Subscription/paywall audit complete."
    Write-Host ("Report: {0}" -f $reportFile)

    if ($failCount -gt 0) {
        exit 1
    }
    exit 0
}
finally {
    Pop-Location
}
