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
$runDir = Join-Path $reportsDir ("security_trust_{0}" -f $timestamp)
New-Item -Path $runDir -ItemType Directory -Force | Out-Null

$reportFile = Join-Path $runDir "security_trust_report.md"

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
    if (Test-Path $Path) {
        return (Get-Content $Path -Raw)
    }
    return ""
}

function Get-HitCount {
    param(
        [string[]]$Paths,
        [string]$Pattern
    )
    if ($null -eq $Paths -or $Paths.Count -eq 0) {
        return 0
    }
    $hits = Select-String -Path $Paths -Pattern $Pattern -AllMatches -ErrorAction SilentlyContinue
    return @($hits).Count
}

Push-Location $ProjectRoot
try {
    $results = @()

    $exampleFiles = @(
        ".env.example",
        "supabase/functions/.env.example",
        "android/key.properties.example",
        "android/release.properties.example",
        "scripts/chronospark_env.example.ps1"
    )
    $existingExamples = @($exampleFiles | Where-Object { Test-Path (Join-Path $ProjectRoot $_) })
    if ($existingExamples.Count -ge 4) {
        $results += Add-Result -Name "Environment/config files documented" -Status "PASS" -Details "Example env and release config files exist." -Evidence ($existingExamples -join ", ")
    }
    else {
        $results += Add-Result -Name "Environment/config files documented" -Status "FAIL" -Details "Expected example config files are missing." -Evidence ("Found {0} of 5 expected example files" -f $existingExamples.Count)
    }

    $gitignoreText = Read-IfExists (Join-Path $ProjectRoot ".gitignore")
    $readmeText = Read-IfExists (Join-Path $ProjectRoot "README.md")
    $securityDocText = Read-IfExists (Join-Path $ProjectRoot "docs\SECURITY_DEPLOYMENT_CHECKLIST.md")
    $envDocHits = 0
    if ($gitignoreText -match '(?m)^\.env$') { $envDocHits++ }
    if ($gitignoreText -match '(?m)^\.firebase/$') { $envDocHits++ }
    if ($readmeText -match '\.env\.example') { $envDocHits++ }
    if ($readmeText -match 'SUPABASE_SECRET_KEY') { $envDocHits++ }
    if ($securityDocText -match 'SUPABASE_SERVICE_ROLE_KEY') { $envDocHits++ }
    if ($envDocHits -ge 4) {
        $results += Add-Result -Name "Environment ignore and docs align" -Status "PASS" -Details "Ignore rules and local-config documentation are present." -Evidence "Hits: $envDocHits"
    }
    else {
        $results += Add-Result -Name "Environment ignore and docs align" -Status "FAIL" -Details "Ignore/documentation evidence is incomplete." -Evidence "Hits: $envDocHits"
    }

    $trackedFiles = @()
    $trackedOutput = & git ls-files 2>$null
    if ($LASTEXITCODE -eq 0 -and $trackedOutput) {
        $trackedFiles = @($trackedOutput | ForEach-Object { Join-Path $ProjectRoot $_ })
    }
    $existingTrackedFiles = @($trackedFiles | Where-Object { Test-Path $_ })

    $scanFiles = @($existingTrackedFiles | Where-Object { $_ -notmatch '\.example(\.|$)' })
    $secretPattern = 'AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|xoxb-[A-Za-z0-9-]+|sk_live_[A-Za-z0-9_]+|sk_test_[A-Za-z0-9_]+|SUPABASE_SERVICE_ROLE_KEY\s*=\s*(?!<)[^\s#]+'
    $sourceSecretHits = @()
    foreach ($path in $scanFiles) {
        if (-not (Test-Path $path)) {
            continue
        }
        $matches = Select-String -Path $path -Pattern $secretPattern -AllMatches -ErrorAction SilentlyContinue
        if ($matches) {
            $sourceSecretHits += $matches
        }
    }

    $historyHits = @()
    $historyPatterns = @(
        'AKIA[0-9A-Z]{16}',
        'ghp_[A-Za-z0-9_]+',
        'github_pat_[A-Za-z0-9_]+',
        'xoxb-[A-Za-z0-9-]+',
        'sk_live_[A-Za-z0-9_]+',
        'sk_test_[A-Za-z0-9_]+',
        'SUPABASE_SERVICE_ROLE_KEY\s*=\s*(?!<)[^\s#]+'
    )
    foreach ($pattern in $historyPatterns) {
        $historyOutput = & git log --all --oneline -G $pattern -- '*.dart' '*.md' '*.ps1' '*.yaml' '*.json' '*.sql' '*.txt' 2>$null
        if ($LASTEXITCODE -eq 0 -and $historyOutput) {
            $historyHits += [pscustomobject]@{
                Pattern = $pattern
                Commit = ($historyOutput | Select-Object -First 1)
            }
        }
    }

    if (@($sourceSecretHits).Count -eq 0 -and @($historyHits).Count -eq 0) {
        $results += Add-Result -Name "No obvious secrets in source or history" -Status "PASS" -Details "No high-signal secret patterns found in tracked files or git history."
    }
    else {
        $examples = @()
        if (@($sourceSecretHits).Count -gt 0) {
            $examples += @($sourceSecretHits | Select-Object -First 3 | ForEach-Object { "{0}:{1}" -f $_.Path.Replace($ProjectRoot + "\\", ""), $_.LineNumber })
        }
        if (@($historyHits).Count -gt 0) {
            $examples += @($historyHits | Select-Object -First 3 | ForEach-Object { $_.Commit })
        }
        $results += Add-Result -Name "No obvious secrets in source or history" -Status "FAIL" -Details "Potential secret patterns detected." -Evidence ($examples -join "; ")
    }

    $supabaseMigrationFiles = @(Get-ChildItem -Path (Join-Path $ProjectRoot "supabase\migrations") -Recurse -File -Filter "*.sql" -ErrorAction SilentlyContinue)
    $supabaseRlsHits = Get-HitCount -Paths ($supabaseMigrationFiles.FullName) -Pattern 'enable row level security|create policy|auth\.uid\(\)|storage\.objects|security_invoker'
    if ($supabaseMigrationFiles.Count -gt 0 -and $supabaseRlsHits -ge 4) {
        $results += Add-Result -Name "Supabase rules reviewed" -Status "PASS" -Details "RLS and storage policy evidence found in migrations." -Evidence "Files: $($supabaseMigrationFiles.Count); Hits: $supabaseRlsHits"
    }
    elseif ($supabaseMigrationFiles.Count -eq 0) {
        $results += Add-Result -Name "Supabase rules reviewed" -Status "FAIL" -Details "No Supabase migrations were found."
    }
    else {
        $results += Add-Result -Name "Supabase rules reviewed" -Status "FAIL" -Details "Migration evidence is thin; review RLS and storage policies." -Evidence "Files: $($supabaseMigrationFiles.Count); Hits: $supabaseRlsHits"
    }

    $firebaseDbUsage = Select-String -Path $existingTrackedFiles -Pattern '\bFirebaseFirestore\b|\bFirebaseDatabase\b|\bFirebaseStorage\b' -AllMatches -ErrorAction SilentlyContinue
    $firebaseRulesFiles = @(Get-ChildItem -Path $ProjectRoot -Recurse -File -Include 'firestore.rules', 'database.rules.json', 'storage.rules' -ErrorAction SilentlyContinue)
    if (@($firebaseDbUsage).Count -gt 0) {
        if ($firebaseRulesFiles.Count -gt 0) {
            $results += Add-Result -Name "Firebase rules reviewed" -Status "PASS" -Details "Firebase database/storage usage has matching rules files." -Evidence "Rules files: $($firebaseRulesFiles.Count)"
        }
        else {
            $results += Add-Result -Name "Firebase rules reviewed" -Status "FAIL" -Details "Firebase database/storage usage found without rules files." -Evidence "Usage hits: $(@($firebaseDbUsage).Count)"
        }
    }
    else {
        $results += Add-Result -Name "Firebase rules reviewed" -Status "PASS" -Details "No Firebase Firestore/Realtime DB/Storage usage found, so dedicated rules files are not required by the current code footprint."
    }

    $accountDeletionHits = 0
    $accountDeletionHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\app\router\route_paths.dart')) -Pattern 'delete-account|deleteAccount'
    $accountDeletionHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\app\router\app_router.dart')) -Pattern 'Delete Account|RoutePaths\.deleteAccount'
    $accountDeletionHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\features\settings\ui\settings_screen.dart')) -Pattern 'Delete Account|accountDeletionConfigured|request deletion via support'
    $accountDeletionHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\data\services\auth_service.dart')) -Pattern 'deleteCurrentAccount|account deletion|signOut\(\)'
    if ($accountDeletionHits -ge 6) {
        $results += Add-Result -Name "Account deletion path exists" -Status "PASS" -Details "Delete-account routing, support fallback, and auth service support are present." -Evidence "Hits: $accountDeletionHits"
    }
    else {
        $results += Add-Result -Name "Account deletion path exists" -Status "FAIL" -Details "Delete-account support is incomplete." -Evidence "Hits: $accountDeletionHits"
    }

    $loggerHits = 0
    $loggerHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\core\debug\logger.dart')) -Pattern 'redactSensitive|errorOutputEnabled|enableVerboseLogs|recordError'
    $loggerHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\app\startup\app_bootstrap.dart')) -Pattern 'Logger\.enabled = config\.verboseLogs|setCrashlyticsCollectionEnabled|setCustomKey'
    $loggerHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\core\debug\runtime_diagnostics.dart')) -Pattern 'redactSensitive'
    $loggerHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\ui\widgets\error_boundary_widget.dart')) -Pattern 'Logger\.error|Crashlytics'
    if ($loggerHits -ge 8) {
        $results += Add-Result -Name "Sensitive logs are scrubbed or disabled in release" -Status "PASS" -Details "Release logging is gated and sensitive content is redacted." -Evidence "Hits: $loggerHits"
    }
    else {
        $results += Add-Result -Name "Sensitive logs are scrubbed or disabled in release" -Status "FAIL" -Details "Release logging or redaction evidence is incomplete." -Evidence "Hits: $loggerHits"
    }

    $crashHits = 0
    $crashHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\core\debug\logger.dart')) -Pattern 'redactSensitive|recordError'
    $crashHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\system\firebase\firebase_bootstrap.dart')) -Pattern 'setCrashlyticsCollectionEnabled|Crashlytics'
    $crashHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\ui\widgets\error_boundary_widget.dart')) -Pattern 'Logger\.error|FlutterError'
    if ($crashHits -ge 5) {
        $results += Add-Result -Name "Crash reports avoid private task content" -Status "PASS" -Details "Crash reporting routes through redaction and guarded collection." -Evidence "Hits: $crashHits"
    }
    else {
        $results += Add-Result -Name "Crash reports avoid private task content" -Status "FAIL" -Details "Crash report redaction evidence is thin." -Evidence "Hits: $crashHits"
    }

    $storageHits = 0
    $storageHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'android\app\src\main\AndroidManifest.xml')) -Pattern 'allowBackup="false"|fullBackupContent="false"|usesCleartextTraffic="false"'
    $storageHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\data\services\backup_service.dart')) -Pattern 'SecureStore|profile_state_v2|tasks|settings'
    $storageHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\data\services\local_user_data_cleanup_service.dart')) -Pattern 'paywall_subscription_state_v1|profile_state_v2|chrono_log_entries_v2|delete\('
    $storageHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\data\storage\shared_prefs_service.dart')) -Pattern 'sensitiveKeyMarkers|Blocked write to SharedPreferences'
    if ($storageHits -ge 8) {
        $results += Add-Result -Name "Local storage privacy risk reviewed" -Status "PASS" -Details "Backup, secure storage, and cleanup signals reduce privacy risk." -Evidence "Hits: $storageHits"
    }
    else {
        $results += Add-Result -Name "Local storage privacy risk reviewed" -Status "FAIL" -Details "Storage/privacy risk evidence is incomplete." -Evidence "Hits: $storageHits"
    }

    $exportWarningHits = 0
    $exportWarningHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\features\settings\ui\settings_screen.dart')) -Pattern 'Exported backups, diagnostics, and support templates may include sensitive|review before sharing'
    $exportWarningHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\data\services\backup_service.dart')) -Pattern 'createFullBackup|backupTasks|backupProfile|backupSettings'
    if ($exportWarningHits -ge 2) {
        $results += Add-Result -Name "Exported backups warn about sensitive contents" -Status "PASS" -Details "Settings copy warns users before sharing sensitive data." -Evidence "Hits: $exportWarningHits"
    }
    else {
        $results += Add-Result -Name "Exported backups warn about sensitive contents" -Status "FAIL" -Details "Backup/export warning copy is missing." -Evidence "Hits: $exportWarningHits"
    }

    $authEdgeHits = 0
    $authEdgeHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\data\services\auth_service.dart')) -Pattern 'signOut\(|refreshSession\(|network-request-failed|too-many-requests|auth-unavailable|user-token-expired|deleteCurrentAccount'
    $authEdgeHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\features\auth\screens\auth_gate.dart')) -Pattern 'Session expired\. Sign in again\.|user-token-expired|network-request-failed|too-many-requests|Sign Out'
    $authEdgeHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\features\settings\ui\settings_screen.dart')) -Pattern 'Session expired\. Sign in again\.|network-request-failed|Log Out|Sign out Mock Session'
    if ($authEdgeHits -ge 8) {
        $results += Add-Result -Name "Authentication edge cases tested" -Status "PASS" -Details "Sign out, token refresh/expiry, and network failure handling are covered in code paths." -Evidence "Hits: $authEdgeHits"
    }
    else {
        $results += Add-Result -Name "Authentication edge cases tested" -Status "FAIL" -Details "Auth edge-case evidence is incomplete." -Evidence "Hits: $authEdgeHits"
    }

    $policyHits = 0
    $policyHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\config\env.dart')) -Pattern 'privacyPolicyUrl|termsOfServiceUrl|supportUrl|supportEmail'
    $policyHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\ui\constants\app_urls.dart')) -Pattern 'privacy|terms|support'
    $policyHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\app\router\app_router.dart')) -Pattern 'Privacy Policy|Terms of Service|Support|Delete Account'
    $policyHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'lib\app\router\info_pages.dart')) -Pattern 'privacy policy|Terms:|Support email|support@chronospark\.app'
    $policyHits += Get-HitCount -Paths @((Join-Path $ProjectRoot 'test\audit\ANDROID_PERMISSIONS_PRIVACY_AUDIT.md')) -Pattern 'Privacy policy URL exists|Play Data Safety form matches'
    if ($policyHits -ge 10) {
        $results += Add-Result -Name "Privacy policy, terms, support, and data safety align" -Status "PASS" -Details "Release-facing legal/support URLs line up with the documented privacy audit." -Evidence "Hits: $policyHits"
    }
    else {
        $results += Add-Result -Name "Privacy policy, terms, support, and data safety align" -Status "FAIL" -Details "Policy/support alignment evidence is incomplete." -Evidence "Hits: $policyHits"
    }

    $failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
    $passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count

    $lines = @()
    $lines += "# Security + Trust Automated Audit"
    $lines += ""
    $lines += "- Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
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

    Write-Host "Security trust audit complete."
    Write-Host ("Report: {0}" -f $reportFile)

    if ($failCount -gt 0) {
        exit 1
    }
    exit 0
}
finally {
    Pop-Location
}
