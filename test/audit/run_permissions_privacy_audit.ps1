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
$runDir = Join-Path $reportsDir ("permissions_privacy_{0}" -f $timestamp)
New-Item -Path $runDir -ItemType Directory -Force | Out-Null

$reportFile = Join-Path $runDir "permissions_privacy_report.md"

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

Push-Location $ProjectRoot
try {
    $results = @()

    $manifestPath = Join-Path $ProjectRoot "android\app\src\main\AndroidManifest.xml"
    if (-not (Test-Path $manifestPath)) {
        $results += Add-Result -Name "Manifest exists" -Status "FAIL" -Details "AndroidManifest.xml not found." -Evidence $manifestPath
    }
    else {
        $manifestText = Get-Content $manifestPath -Raw
        $permissionMatches = [regex]::Matches($manifestText, 'uses-permission\s+android:name="([^"]+)"')
        $permissions = @($permissionMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

        $results += Add-Result -Name "Manifest exists" -Status "PASS" -Details "Manifest found." -Evidence "android/app/src/main/AndroidManifest.xml"

        $requiredPermissions = @(
            "android.permission.INTERNET",
            "com.android.vending.BILLING"
        )
        foreach ($perm in $requiredPermissions) {
            if ($permissions -contains $perm) {
                $results += Add-Result -Name "Required permission: $perm" -Status "PASS" -Details "Declared." -Evidence $perm
            }
            else {
                $results += Add-Result -Name "Required permission: $perm" -Status "FAIL" -Details "Missing expected permission." -Evidence $perm
            }
        }

        $forbiddenV1 = @(
            "android.permission.SCHEDULE_EXACT_ALARM",
            "android.permission.USE_EXACT_ALARM",
            "android.permission.READ_CALENDAR",
            "android.permission.WRITE_CALENDAR",
            "android.permission.ACCESS_FINE_LOCATION",
            "android.permission.ACCESS_COARSE_LOCATION",
            "android.permission.READ_CONTACTS",
            "android.permission.WRITE_CONTACTS",
            "android.permission.MANAGE_EXTERNAL_STORAGE",
            "android.permission.READ_EXTERNAL_STORAGE",
            "android.permission.WRITE_EXTERNAL_STORAGE"
        )

        $foundForbidden = @($permissions | Where-Object { $forbiddenV1 -contains $_ })
        if ($foundForbidden.Count -eq 0) {
            $results += Add-Result -Name "Forbidden V1 permissions absent" -Status "PASS" -Details "No forbidden V1 permissions found."
        }
        else {
            $results += Add-Result -Name "Forbidden V1 permissions absent" -Status "FAIL" -Details ("Found forbidden permissions: " + ($foundForbidden -join ", "))
        }

        if ($permissions -contains "android.permission.POST_NOTIFICATIONS") {
            $notificationUsage = Select-String -Path "lib\**\*.dart" -Pattern "POST_NOTIFICATIONS|Permission\.notification|requestNotificationsPermission|flutter_local_notifications" -AllMatches -ErrorAction SilentlyContinue
            if (@($notificationUsage).Count -gt 0) {
                $results += Add-Result -Name "Notification permission has code usage" -Status "PASS" -Details "Found notification-related code references." -Evidence ("Matches: " + @($notificationUsage).Count)
            }
            else {
                $results += Add-Result -Name "Notification permission has code usage" -Status "FAIL" -Details "Permission declared but no notification permission/request code signals found."
            }
        }

        if ($permissions -contains "android.permission.RECORD_AUDIO") {
            $audioUsage = Select-String -Path "lib\**\*.dart" -Pattern "Permission\.microphone|RECORD_AUDIO|microphone|voice" -AllMatches -ErrorAction SilentlyContinue
            if (@($audioUsage).Count -gt 0) {
                $results += Add-Result -Name "Audio permission has code usage" -Status "PASS" -Details "Found audio/voice-related code references." -Evidence ("Matches: " + @($audioUsage).Count)
            }
            else {
                $results += Add-Result -Name "Audio permission has code usage" -Status "FAIL" -Details "RECORD_AUDIO declared but no clear runtime usage found."
            }
        }

        if ($permissions -contains "android.permission.RECEIVE_BOOT_COMPLETED") {
            if ($manifestText -match "ScheduledNotificationBootReceiver") {
                $results += Add-Result -Name "Boot permission receiver wiring" -Status "PASS" -Details "Boot receiver present for notifications."
            }
            else {
                $results += Add-Result -Name "Boot permission receiver wiring" -Status "FAIL" -Details "RECEIVE_BOOT_COMPLETED declared without receiver wiring evidence."
            }
        }
    }

    $privacyCandidates = @(
        "privacy.html",
        "privacy-policy",
        "assets\legal\privacy_policy.txt"
    )
    $privacyFound = $false
    foreach ($p in $privacyCandidates) {
        if (Test-Path (Join-Path $ProjectRoot $p)) {
            $privacyFound = $true
            break
        }
    }
    if ($privacyFound) {
        $results += Add-Result -Name "Privacy policy artifact exists" -Status "PASS" -Details "Found at least one privacy policy artifact."
    }
    else {
        $results += Add-Result -Name "Privacy policy artifact exists" -Status "FAIL" -Details "No expected privacy policy artifact found."
    }

    $secretPatterns = @(
        "service_role",
        "SUPABASE_SERVICE_ROLE",
        "AKIA[0-9A-Z]{16}",
        "AIza[0-9A-Za-z_\-]{35}",
        "-----BEGIN (RSA|EC|PRIVATE) KEY-----"
    )
    $secretRegex = ($secretPatterns -join "|")

    $candidateFiles = Get-ChildItem -Recurse -File | Where-Object {
        $_.FullName -notmatch "\\build\\|\\.dart_tool\\|\\test\\audit\\reports\\|\\android\\app\\build\\"
    }

    $secretHits = @()
    foreach ($file in $candidateFiles) {
        $m = Select-String -Path $file.FullName -Pattern $secretRegex -AllMatches -ErrorAction SilentlyContinue
        if ($m) {
            $secretHits += $m
        }
    }

    if ($secretHits.Count -eq 0) {
        $results += Add-Result -Name "No obvious committed secrets" -Status "PASS" -Details "No high-signal secret patterns found."
    }
    else {
        $examples = @($secretHits | Select-Object -First 5 | ForEach-Object { "{0}:{1}" -f $_.Path.Replace($ProjectRoot + "\\", ""), $_.LineNumber })
        $results += Add-Result -Name "No obvious committed secrets" -Status "FAIL" -Details "Potential secret patterns detected." -Evidence ($examples -join "; ")
    }

    $failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
    $passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count

    $lines = @()
    $lines += "# Android Permissions + Privacy Automated Audit"
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

    Write-Host "Permissions/privacy audit complete."
    Write-Host ("Report: {0}" -f $reportFile)

    if ($failCount -gt 0) {
        exit 1
    }
    exit 0
}
finally {
    Pop-Location
}
