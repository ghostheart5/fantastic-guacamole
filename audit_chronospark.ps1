# ============================================================
# ChronoSpark Full Flutter Project Audit Script
# Run from project root:
# powershell -ExecutionPolicy Bypass -File .\audit_chronospark.ps1
# ============================================================

$ErrorActionPreference = "Continue"

$ProjectRoot = Get-Location
$ReportDir = Join-Path $ProjectRoot "audit_reports"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ReportFile = Join-Path $ReportDir "chronospark_audit_$Timestamp.txt"

if (!(Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir | Out-Null
}

function Write-Section {
    param([string]$Title)

    $line = "`n============================================================"
    Add-Content -Path $ReportFile -Value $line -Encoding UTF8
    Add-Content -Path $ReportFile -Value $Title -Encoding UTF8
    Add-Content -Path $ReportFile -Value "============================================================`n" -Encoding UTF8

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-Report {
    param([string]$Text)
    Add-Content -Path $ReportFile -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Test-PathReport {
    param(
        [string]$Path,
        [string]$Label
    )

    if (Test-Path $Path) {
        Write-Report "[PASS] $Label found: $Path"
    }
    else {
        Write-Report "[WARN] $Label missing: $Path"
    }
}

function Search-Pattern {
    param(
        [string]$Label,
        [string]$Pattern,
        [string]$Path = "lib"
    )

    Write-Report "`n--- $Label ---"

    if (!(Test-Path $Path)) {
        Write-Report "[WARN] Path not found: $Path"
        return
    }

    $results = Get-ChildItem $Path -Recurse -Include *.dart, *.yaml, *.yml, *.json, *.kt, *.gradle, *.kts, *.md -ErrorAction SilentlyContinue |
    Select-String -Pattern $Pattern -ErrorAction SilentlyContinue

    if ($results) {
        foreach ($r in $results) {
            Write-Report "$($r.Path):$($r.LineNumber): $($r.Line.Trim())"
        }
    }
    else {
        Write-Report "[OK] No matches found."
    }
}

function Count-Files {
    param(
        [string]$Label,
        [string]$Path,
        [string]$Filter = "*.dart"
    )

    if (Test-Path $Path) {
        $count = (Get-ChildItem $Path -Recurse -Filter $Filter -ErrorAction SilentlyContinue | Measure-Object).Count
        Write-Report "${Label}: $count"
    }
    else {
        Write-Report "${Label}: path missing"
    }
}

function Invoke-AuditCommand {
    param(
        [string]$Name,
        [string]$Command,
        [switch]$TreatAsWarning
    )

    Write-Report "`nRunning $Name..."

    try {
        $commandOutput = @(Invoke-Expression "$Command 2>&1")
        foreach ($line in $commandOutput) {
            Write-Report ([string]$line)
        }
        $exitCode = $LASTEXITCODE

        if ($null -eq $exitCode) {
            $exitCode = 0
        }

        if ($exitCode -eq 0) {
            Write-Report "[PASS] $Name completed (exit code 0)."
            return @{ Name = $Name; Status = "PASS"; ExitCode = $exitCode }
        }

        if ($TreatAsWarning) {
            Write-Report "[WARN] $Name returned non-zero exit code ($exitCode)."
            return @{ Name = $Name; Status = "WARN"; ExitCode = $exitCode }
        }

        Write-Report "[FAIL] $Name failed (exit code $exitCode)."
        return @{ Name = $Name; Status = "FAIL"; ExitCode = $exitCode }
    }
    catch {
        $level = if ($TreatAsWarning) { "WARN" } else { "FAIL" }
        Write-Report "[$level] $Name threw an exception: $($_.Exception.Message)"
        return @{ Name = $Name; Status = $level; ExitCode = -1 }
    }
}

Clear-Host

Write-Host "Starting ChronoSpark full audit..." -ForegroundColor Green
Write-Host "Project root: $ProjectRoot"
Write-Host "Report file: $ReportFile"

Set-Content -Path $ReportFile -Value "ChronoSpark Full Project Audit" -Encoding UTF8
Add-Content -Path $ReportFile -Value "Generated: $(Get-Date)" -Encoding UTF8
Add-Content -Path $ReportFile -Value "Project Root: $ProjectRoot" -Encoding UTF8

# ============================================================
# 1. ROOT PROJECT CHECK
# ============================================================

Write-Section "1. Root Project Check"

Test-PathReport "pubspec.yaml" "pubspec.yaml"
Test-PathReport "lib" "lib folder"
Test-PathReport "android" "android folder"
Test-PathReport "test" "test folder"
Test-PathReport "integration_test" "integration_test folder"
Test-PathReport ".git" "Git repository"
Test-PathReport "README.md" "README"

# ============================================================
# 2. FLUTTER / DART VERSION INFO
# ============================================================

Write-Section "2. Flutter and Dart Info"

try {
    $flutterVersion = flutter --version
    Add-Content -Path $ReportFile -Value $flutterVersion -Encoding UTF8
    Write-Host $flutterVersion
}
catch {
    Write-Report "[ERROR] Flutter command failed. Is Flutter installed and in PATH?"
}

try {
    $dartVersion = dart --version 2>&1
    Add-Content -Path $ReportFile -Value $dartVersion -Encoding UTF8
    Write-Host $dartVersion
}
catch {
    Write-Report "[ERROR] Dart command failed."
}

# ============================================================
# 3. PUBSPEC DEPENDENCY AUDIT
# ============================================================

Write-Section "3. Pubspec Dependency Audit"

if (Test-Path "pubspec.yaml") {
    $pubspec = Get-Content "pubspec.yaml"

    Write-Report "--- Dependencies found in pubspec.yaml ---"

    $dependencyNames = @()
    $insideDependencies = $false

    foreach ($line in $pubspec) {
        if ($line -match "^dependencies:") {
            $insideDependencies = $true
            continue
        }

        if ($line -match "^dev_dependencies:") {
            $insideDependencies = $false
            continue
        }

        if ($insideDependencies -and $line -match "^\s{2}([a-zA-Z0-9_]+):") {
            $name = $Matches[1]
            if ($name -ne "flutter") {
                $dependencyNames += $name
                Write-Report "dependency: $name"
            }
        }
    }

    Write-Report "`n--- Dependency import usage scan ---"

    foreach ($dep in $dependencyNames) {
        $pattern = "package:$dep/"
        $matches = Get-ChildItem "lib" -Recurse -Filter *.dart -ErrorAction SilentlyContinue |
        Select-String -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue

        if ($matches) {
            Write-Report "[USED] $dep"
        }
        else {
            Write-Report "[CHECK] $dep installed but no direct import found in lib/"
        }
    }
}
else {
    Write-Report "[ERROR] pubspec.yaml missing."
}

# ============================================================
# 4. FEATURE FOLDER AUDIT
# ============================================================

Write-Section "4. Feature Folder Audit"

Test-PathReport "lib\core" "core folder"
Test-PathReport "lib\app" "app folder"
Test-PathReport "lib\features" "features folder"
if (Test-Path "lib\shared") {
    Write-Report "[PASS] optional shared folder found: lib\\shared"
}
else {
    Write-Report "[INFO] optional shared folder not present: lib\\shared"
}

$expectedFeatures = @(
    "admin",
    "auth",
    "coach",
    "creator",
    "docs",
    "emotion",
    "flowmap",
    "focus",
    "goals",
    "help",
    "home",
    "insights",
    "logs",
    "memories",
    "milestones",
    "nexus",
    "notifications",
    "onboarding",
    "paywall",
    "permissions",
    "plan",
    "profile",
    "progression",
    "settings",
    "si_console",
    "soul_map",
    "support",
    "tasks",
    "timeline"
)

Write-Report "`n--- Expected feature folders ---"

foreach ($feature in $expectedFeatures) {
    $path = "lib\features\$feature"
    if (Test-Path $path) {
        Write-Report "[PASS] feature exists: $feature"
    }
    else {
        Write-Report "[MISSING] feature missing: $feature"
    }
}

Write-Report "`n--- Existing feature folders ---"

if (Test-Path "lib\features") {
    Get-ChildItem "lib\features" -Directory | ForEach-Object {
        Write-Report "feature: $($_.Name)"
    }
}

# ============================================================
# 5. CLEAN ARCHITECTURE LAYER AUDIT
# ============================================================

Write-Section "5. Clean Architecture Layer Audit"

if (Test-Path "lib\features") {
    foreach ($featureDir in Get-ChildItem "lib\features" -Directory) {
        Write-Report "`nFeature: $($featureDir.Name)"

        $domain = Join-Path $featureDir.FullName "domain"
        $data = Join-Path $featureDir.FullName "data"
        $presentation = Join-Path $featureDir.FullName "presentation"
        $application = Join-Path $featureDir.FullName "application"

        if (Test-Path $domain) { Write-Report "  [OK] domain" } else { Write-Report "  [INFO] no domain layer" }
        if (Test-Path $data) { Write-Report "  [OK] data" } else { Write-Report "  [INFO] no data layer" }
        if (Test-Path $presentation) { Write-Report "  [OK] presentation" } else { Write-Report "  [INFO] no presentation layer" }
        if (Test-Path $application) { Write-Report "  [OK] application" } else { Write-Report "  [INFO] no application layer" }

        Count-Files "  Dart files" $featureDir.FullName
    }
}

# ============================================================
# 6. ENTITY / MODEL / USECASE / REPOSITORY AUDIT
# ============================================================

Write-Section "6. Entity, Model, Use Case, Repository Audit"

$foldersToCount = @(
    "entities",
    "models",
    "usecases",
    "repositories",
    "datasources",
    "providers",
    "controllers",
    "screens",
    "widgets",
    "services"
)

foreach ($folder in $foldersToCount) {
    $count = 0

    if (Test-Path "lib") {
        $count = (Get-ChildItem "lib" -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $folder } |
            Measure-Object).Count
    }

    Write-Report "$folder folders found: $count"
}

Write-Report "`n--- Dart file naming scan ---"

$namingPatterns = @(
    "*entity.dart",
    "*model.dart",
    "*usecase.dart",
    "*repository.dart",
    "*provider.dart",
    "*controller.dart",
    "*service.dart",
    "*screen.dart",
    "*widget.dart"
)

foreach ($pattern in $namingPatterns) {
    $count = (Get-ChildItem "lib" -Recurse -Filter $pattern -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Report "$pattern count: $count"
}

# ============================================================
# 7. PLACEHOLDER / TODO / DUMMY CODE AUDIT
# ============================================================

Write-Section "7. Placeholder, TODO, Dummy Code Audit"

Search-Pattern "TODO markers" "TODO"
Search-Pattern "FIXME markers" "FIXME"
Search-Pattern "placeholder references" "placeholder"
Search-Pattern "dummy references" "dummy"
Search-Pattern "fake references" "fake"
Search-Pattern "mock references" "mock"
Search-Pattern "UnimplementedError usage" "UnimplementedError"
Search-Pattern "throw Exception generic usage" "throw Exception"
Search-Pattern "print statements" "print\("
Search-Pattern "debugPrint statements" "debugPrint"
Search-Pattern "hardcoded example text" "example"
Search-Pattern "coming soon references" "coming soon"

# ============================================================
# 8. FIREBASE AUDIT
# ============================================================

Write-Section "8. Firebase Audit"

Test-PathReport "lib\firebase_options.dart" "firebase_options.dart"
Test-PathReport "android\app\google-services.json" "google-services.json"

Search-Pattern "Firebase.initializeApp usage" "Firebase.initializeApp"
Search-Pattern "Firebase Analytics usage" "FirebaseAnalytics"
Search-Pattern "Firebase Crashlytics usage" "FirebaseCrashlytics"
Search-Pattern "Firebase Remote Config usage" "FirebaseRemoteConfig"
Search-Pattern "FlutterError.onError Crashlytics hook" "FlutterError.onError"
Search-Pattern "PlatformDispatcher error hook" "PlatformDispatcher.instance.onError"
Search-Pattern "Analytics logEvent calls" "logEvent"
Search-Pattern "Analytics screen view calls" "logScreenView"

Write-Report "`n--- Android Firebase Gradle plugin scan ---"

Search-Pattern "Google services Gradle plugin" "com.google.gms.google-services" "android"
Search-Pattern "Crashlytics Gradle plugin" "com.google.firebase.crashlytics" "android"

# ============================================================
# 9. SUPABASE AUDIT
# ============================================================

Write-Section "9. Supabase Audit"

Search-Pattern "Supabase.initialize usage" "Supabase.initialize"
Search-Pattern "Supabase.instance.client usage" "Supabase.instance.client"
Search-Pattern "Supabase auth usage" "\.auth"
Search-Pattern "Supabase from table usage" "\.from\("
Search-Pattern "Supabase URL references" "SUPABASE_URL|supabaseUrl|supabase_url"
Search-Pattern "Supabase anon key references" "SUPABASE_ANON|anonKey|anon_key"

Write-Report "`n[SECURITY CHECK] Searching for possible service role keys..."
Search-Pattern "Possible Supabase service role key" "service_role|service-role|SERVICE_ROLE"

# ============================================================
# 10. HIVE / LOCAL STORAGE AUDIT
# ============================================================

Write-Section "10. Hive and Local Storage Audit"

Search-Pattern "Hive.initFlutter usage" "Hive.initFlutter"
Search-Pattern "Hive.openBox usage" "Hive.openBox"
Search-Pattern "Hive.box usage" "Hive.box"
Search-Pattern "Hive TypeAdapter usage" "TypeAdapter"
Search-Pattern "SharedPreferences usage" "SharedPreferences"
Search-Pattern "FlutterSecureStorage usage" "FlutterSecureStorage"

# ============================================================
# 11. RIVERPOD AUDIT
# ============================================================

Write-Section "11. Riverpod Audit"

Search-Pattern "ProviderScope usage" "ProviderScope"
Search-Pattern "Provider usage" "Provider<|Provider\("
Search-Pattern "StateProvider usage" "StateProvider"
Search-Pattern "FutureProvider usage" "FutureProvider"
Search-Pattern "StreamProvider usage" "StreamProvider"
Search-Pattern "NotifierProvider usage" "NotifierProvider"
Search-Pattern "AsyncNotifier usage" "AsyncNotifier"
Search-Pattern "ConsumerWidget usage" "ConsumerWidget"
Search-Pattern "ref.watch usage" "ref.watch"
Search-Pattern "ref.read usage" "ref.read"

# ============================================================
# 12. ROUTING AUDIT
# ============================================================

Write-Section "12. GoRouter and Navigation Audit"

Search-Pattern "GoRouter usage" "GoRouter"
Search-Pattern "GoRoute usage" "GoRoute"
Search-Pattern "ShellRoute usage" "ShellRoute"
Search-Pattern "redirect usage" "redirect:"
Search-Pattern "context.go usage" "context.go"
Search-Pattern "context.push usage" "context.push"
Search-Pattern "Navigator direct usage" "Navigator\."

# ============================================================
# 13. NOTIFICATIONS / TIMEZONE AUDIT
# ============================================================

Write-Section "13. Notifications and Timezone Audit"

Search-Pattern "FlutterLocalNotificationsPlugin usage" "FlutterLocalNotificationsPlugin"
Search-Pattern "notification initialize usage" "\.initialize\("
Search-Pattern "zonedSchedule usage" "zonedSchedule"
Search-Pattern "timezone initialize usage" "initializeTimeZones"
Search-Pattern "tz location usage" "tz\."
Search-Pattern "Notification permission usage" "requestPermissions|requestPermission"

# ============================================================
# 14. CONNECTIVITY / OFFLINE / SYNC AUDIT
# ============================================================

Write-Section "14. Connectivity, Offline, Sync Audit"

Search-Pattern "connectivity_plus usage" "Connectivity"
Search-Pattern "offline references" "offline"
Search-Pattern "sync references" "sync"
Search-Pattern "queue references" "queue"
Search-Pattern "limited mode references" "limited mode|LimitedMode|limitedMode"
Search-Pattern "retry references" "retry"

# ============================================================
# 15. SMART COACH AUDIT
# ============================================================

Write-Section "15. Smart Coach Audit"

Search-Pattern "Smart Coach references" "SmartCoach|smart_coach|smart coach"
Search-Pattern "Coach intent references" "CoachIntent|coachIntent|coach_intent"
Search-Pattern "Coach response references" "CoachResponse|coachResponse|coach_response"
Search-Pattern "Coach context references" "CoachContext|coachContext|coach_context"
Search-Pattern "Intent detection references" "IntentDetection|detectIntent|intent detection"
Search-Pattern "Prompt builder references" "PromptBuilder|buildPrompt|prompt builder"
Search-Pattern "AI response references" "AiResponse|AIResponse|ai_response"

# ============================================================
# 16. SI CONSOLE AUDIT
# ============================================================

Write-Section "16. SI Console Audit"

Search-Pattern "SI Console references" "SiConsole|SIConsole|si_console|SI Console"
Search-Pattern "SI Query references" "SiQuery|SIQuery|si_query"
Search-Pattern "SI Response references" "SiResponse|SIResponse|si_response"
Search-Pattern "System analysis references" "SystemAnalysis|systemAnalysis|system analysis"
Search-Pattern "Recommendation engine references" "RecommendationEngine|recommendation engine"
Search-Pattern "Priority engine references" "PriorityEngine|priority engine"
Search-Pattern "Timeline analysis references" "TimelineAnalysis|timeline analysis"

# ============================================================
# 17. CORE FEATURE AUDIT
# ============================================================

Write-Section "17. Core Feature Keyword Audit"

$coreKeywords = @(
    "Goal",
    "Milestone",
    "Task",
    "Project",
    "Habit",
    "Streak",
    "Timeline",
    "DailyPlan",
    "WeeklyPlan",
    "Memory",
    "Journal",
    "SoulMap",
    "CoreValue",
    "FutureSelf",
    "Momentum",
    "Analytics",
    "Reminder",
    "Notification",
    "Subscription",
    "Entitlement"
)

foreach ($keyword in $coreKeywords) {
    Search-Pattern "$keyword references" $keyword
}

# ============================================================
# 18. SECURITY AUDIT
# ============================================================

Write-Section "18. Security and Secret Audit"

Search-Pattern "Possible hardcoded API keys" "apiKey|api_key|API_KEY|secret|SECRET|privateKey|PRIVATE_KEY"
Search-Pattern "Possible tokens" "token|TOKEN|accessToken|refreshToken"
Search-Pattern "Supabase service role leak" "service_role|SERVICE_ROLE"
Search-Pattern "Google services package name" "package_name" "android"
Search-Pattern "Android applicationId" "applicationId" "android"

Write-Report "`n[NOTE] Supabase anon key is public-safe, but service_role key must NEVER be inside Flutter app."

# ============================================================
# 19. GOOGLE PLAY READINESS AUDIT
# ============================================================

Write-Section "19. Google Play Readiness Audit"

Search-Pattern "version in pubspec" "^version:" "."
Search-Pattern "applicationId" "applicationId" "android"
Search-Pattern "minSdk" "minSdk" "android"
Search-Pattern "targetSdk" "targetSdk" "android"
Search-Pattern "versionCode" "versionCode" "android"
Search-Pattern "versionName" "versionName" "android"
Search-Pattern "INTERNET permission" "android.permission.INTERNET" "android"
Search-Pattern "notification permission" "POST_NOTIFICATIONS" "android"
Search-Pattern "billing permission" "com.android.vending.BILLING" "android"

Test-PathReport "android\app\src\main\AndroidManifest.xml" "AndroidManifest.xml"

# ============================================================
# 20. LEGAL / PRIVACY AUDIT
# ============================================================

Write-Section "20. Legal and Privacy Audit"

Search-Pattern "Privacy policy references" "privacy policy|PrivacyPolicy|privacy_policy"
Search-Pattern "Terms references" "terms of service|TermsOfService|terms_of_service"
Search-Pattern "Delete account references" "delete account|DeleteAccount|delete_account"
Search-Pattern "Data export references" "export data|DataExport|data_export"
Search-Pattern "Consent references" "consent|Consent"

# ============================================================
# 21. TEST FILE AUDIT
# ============================================================

Write-Section "21. Test File Audit"

Count-Files "lib Dart files" "lib"
Count-Files "test Dart files" "test"
Count-Files "integration_test Dart files" "integration_test"

Write-Report "`n--- Test keyword scan ---"
Search-Pattern "Unit test references" "test\(" "test"
Search-Pattern "Widget test references" "testWidgets" "test"
Search-Pattern "Integration test references" "IntegrationTestWidgetsFlutterBinding" "integration_test"

# ============================================================
# 22. FLUTTER COMMAND AUDIT
# ============================================================

Write-Section "22. Flutter Command Audit"

$commandResults = @()

$commandResults += Invoke-AuditCommand -Name "flutter pub get" -Command "flutter pub get"
$commandResults += Invoke-AuditCommand -Name "dart format check" -Command "dart format --output=none lib test --set-exit-if-changed" -TreatAsWarning
$commandResults += Invoke-AuditCommand -Name "flutter analyze" -Command "flutter analyze"
$commandResults += Invoke-AuditCommand -Name "flutter test" -Command "flutter test"

Write-Report "`n--- Command Audit Scoreboard ---"
foreach ($result in $commandResults) {
    Write-Report "[$($result.Status)] $($result.Name) (exit code $($result.ExitCode))"
}

# Build checks are useful but can take time.
# Uncomment if you want automatic build checks every audit.

# Write-Report "`nRunning flutter build apk --debug..."
# try {
#     flutter build apk --debug 2>&1 | Tee-Object -FilePath $ReportFile -Append
# } catch {
#     Write-Report "[WARN] debug APK build failed."
# }

# Write-Report "`nRunning flutter build appbundle..."
# try {
#     flutter build appbundle 2>&1 | Tee-Object -FilePath $ReportFile -Append
# } catch {
#     Write-Report "[WARN] appbundle build failed."
# }

# ============================================================
# 23. FINAL SUMMARY
# ============================================================

Write-Section "23. Final Audit Summary"

$failedCommands = @($commandResults | Where-Object { $_.Status -eq "FAIL" })
$warnedCommands = @($commandResults | Where-Object { $_.Status -eq "WARN" })

if ($failedCommands.Count -eq 0 -and $warnedCommands.Count -eq 0) {
    Write-Report "Overall command status: PASS"
}
elseif ($failedCommands.Count -eq 0 -and $warnedCommands.Count -gt 0) {
    Write-Report "Overall command status: PASS with warnings"
}
else {
    Write-Report "Overall command status: FAIL"
}

Write-Report "Audit complete."
Write-Report "Report saved to:"
Write-Report $ReportFile

if ($failedCommands.Count -gt 0) {
    Write-Report "`nFailed commands:"
    foreach ($item in $failedCommands) {
        Write-Report "- $($item.Name) (exit code $($item.ExitCode))"
    }
}

if ($warnedCommands.Count -gt 0) {
    Write-Report "`nWarning commands:"
    foreach ($item in $warnedCommands) {
        Write-Report "- $($item.Name) (exit code $($item.ExitCode))"
    }
}

Write-Report "`nNext manual checks:"
Write-Report "[ ] Supabase project exists"
Write-Report "[ ] Supabase URL and anon key are configured"
Write-Report "[ ] Supabase Auth email signup is enabled"
Write-Report "[ ] Supabase RLS policies exist"
Write-Report "[ ] Firebase project matches Android package name"
Write-Report "[ ] Firebase Analytics realtime events appear"
Write-Report "[ ] Crashlytics receives test crash"
Write-Report "[ ] Remote Config fetches values"
Write-Report "[ ] Google Play package name matches app"
Write-Report "[ ] Internal/closed testing install works"
Write-Report "[ ] Account creation works on real device"
Write-Report "[ ] Login works on real device"
Write-Report "[ ] Smart Coach gives topic-specific answers"
Write-Report "[ ] SI Console reads real goals/tasks/habits"
Write-Report "[ ] Offline/limited mode is clear and does not break app"
Write-Report "[ ] Privacy policy URL works"
Write-Report "[ ] Delete account URL works"

Write-Host ""
Write-Host "Audit finished." -ForegroundColor Green
Write-Host "Report saved to: $ReportFile" -ForegroundColor Yellow
