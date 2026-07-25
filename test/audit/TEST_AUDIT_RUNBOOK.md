# ChronoSpark Test Audit Runbook

Date: 2026-07-24
Scope: Execute release audit checks with reproducible commands and objective pass/fail signals.

## How to use this runbook
1. Open [test/audit/TEST_AUDIT_MASTER_MAP.md](test/audit/TEST_AUDIT_MASTER_MAP.md).
2. Open [test/audit/HUMAN_LIKE_E2E_TESTING_PLAN.md](test/audit/HUMAN_LIKE_E2E_TESTING_PLAN.md) for user-like smoke flow validation.
3. Open [test/audit/ANDROID_PERMISSIONS_PRIVACY_AUDIT.md](test/audit/ANDROID_PERMISSIONS_PRIVACY_AUDIT.md) for permission minimization and Data Safety review.
4. Open [test/audit/VISUAL_DESIGN_PREMIUM_FEEL_AUDIT.md](test/audit/VISUAL_DESIGN_PREMIUM_FEEL_AUDIT.md) for premium feel and readability checks.
5. Open [test/audit/PERFORMANCE_STABILITY_AUDIT.md](test/audit/PERFORMANCE_STABILITY_AUDIT.md) for performance and stability validation.
6. Open [test/audit/SUBSCRIPTION_PAYWALL_AUDIT.md](test/audit/SUBSCRIPTION_PAYWALL_AUDIT.md) for tier and monetization validation.
7. Open [test/audit/ACCESSIBILITY_REAL_USER_USABILITY_AUDIT.md](test/audit/ACCESSIBILITY_REAL_USER_USABILITY_AUDIT.md) for accessibility and real-user usability validation.
8. Open [test/audit/SECURITY_TRUST_AUDIT.md](test/audit/SECURITY_TRUST_AUDIT.md) for secrets, storage, auth, crash, and policy alignment validation.
9. Work section-by-section using commands below.
10. Record output snippets and decision notes in Evidence/Notes.
11. If any blocker appears, log issue ID and stop go-live until retest passes.

## Automated runner
Run the script from project root to execute the core audit and generate report artifacts.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\audit\run_audit.ps1
```

Optional flags:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\audit\run_audit.ps1 -NoWindowsBuild -NoAndroidReleaseBuild
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\audit\run_audit.ps1 -NoWindowsBuild -NoAndroidReleaseBuild -NoPermissionsPrivacyAudit -NoVisualDesignAudit
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\audit\run_audit.ps1 -NoWindowsBuild -NoAndroidReleaseBuild -NoPermissionsPrivacyAudit -NoVisualDesignAudit -NoPerformanceStabilityAudit
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\audit\run_audit.ps1 -NoWindowsBuild -NoAndroidReleaseBuild -NoPermissionsPrivacyAudit -NoVisualDesignAudit -NoPerformanceStabilityAudit -NoSubscriptionPaywallAudit
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\audit\run_audit.ps1 -NoWindowsBuild -NoAndroidReleaseBuild -NoPermissionsPrivacyAudit -NoVisualDesignAudit -NoPerformanceStabilityAudit -NoSubscriptionPaywallAudit -NoAccessibilityAudit
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\audit\run_audit.ps1 -NoWindowsBuild -NoAndroidReleaseBuild -NoPermissionsPrivacyAudit -NoVisualDesignAudit -NoPerformanceStabilityAudit -NoSubscriptionPaywallAudit -NoAccessibilityAudit -NoSecurityTrustAudit
```

## Section 2: Baseline Backup + Environment

### Commands
```powershell
pwd
git status --short
git branch --show-current
git rev-parse --short HEAD
git log --oneline -n 20
git tag --sort=-creatordate | Select-Object -First 20
flutter --version
dart --version
flutter doctor -v
flutter devices
Get-Process | Where-Object { $_.ProcessName -in @('flutter','dart','msbuild','gradle','java') } | Select-Object ProcessName,Id,CPU
```

### Pass criteria
- Project path matches expected repository.
- Git status captured before edits.
- Current branch and last good commit/tag recorded.
- Flutter and Dart versions are present and valid.
- flutter doctor -v has no blocking errors.
- At least one intended debug target device is visible.
- No unknown long-running command blocks next steps.

### Failure signatures
- flutter not recognized
- dart not recognized
- doctor reports missing Android toolchain/licenses
- no devices found

## Section 3: Analyze / Test / Build Gate

### Commands
```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --debug
flutter build appbundle --release
```

### Pass criteria
- pub get exits 0.
- analyze exits 0 with no issues.
- test exits 0.
- debug build exits 0.
- release appbundle command is documented and runnable in CI/release env.

### Failure signatures
- Analyzer errors (undefined names, invalid overrides, type errors)
- Test failures/exceptions
- Gradle plugin mismatch, Kotlin version errors, AGP incompatibility
- Windows lock errors like C1083 permission denied

### Known recovery snippets
```powershell
Get-Process | Where-Object { $_.ProcessName -in @('cl','MSBuild','vctip','devenv') } | Stop-Process -Force -ErrorAction SilentlyContinue
flutter clean
flutter pub get
```

## Section 4: Dead Code + Wiring

### Commands
```powershell
Get-ChildItem lib -Recurse -File | Select-Object FullName
Select-String -Path lib\**\*.dart -Pattern "GoRoute\(|routes\s*=|NavigationShell|context\.push|context\.go"
Select-String -Path lib\**\*.dart -Pattern "Provider\(|StateNotifierProvider|NotifierProvider|AsyncNotifierProvider|ref\.watch|ref\.read"
```

### Pass criteria
- Every release screen is reachable from route/shell/parent.
- Every provider/controller has a consumer.
- Unused future-only code is marked ARCHIVE/FUTURE and excluded from release path.

### Classification labels
- CONNECT
- ARCHIVE
- MERGE
- CUT FROM V1

## Section 5: Provider / Controller / Repository

### Commands
```powershell
Select-String -Path lib\**\*.dart -Pattern "class .*Controller|class .*Notifier|extends .*Notifier|extends StateNotifier"
Select-String -Path lib\**\*.dart -Pattern "Repository|Service|DataSource|Persistence"
Select-String -Path lib\**\*.dart -Pattern "ref\.invalidate|autoDispose|keepAlive"
```

### Pass criteria
- UI routes state changes through provider/controller boundaries.
- Loading/data/error states exist for async paths.
- No circular provider dependencies.
- Critical state survives expected tab switches.

## Section 6: Navigation + Back Blockers

### Commands
```powershell
flutter test test/navigation
flutter test test/navigation/navigation_shell_back_test.dart
flutter test test/navigation/navigation_shell_open_views_test.dart
```

### Manual smoke flow
1. Launch -> Nexus
2. Nexus -> Smart Coach -> Back
3. Nexus -> Add -> Back
4. Settings -> Paywall -> Back
5. Open each tab repeatedly

### Pass criteria
- No crash/exception during route entry/exit.
- Back always returns to defined destination.
- No disposed-state reads or setState-after-dispose errors.

## Section 7: Core Feature Flows

### Manual checklist
1. Launch and hydrate from empty and existing state.
2. Create task and verify list + SI recompute.
3. Complete task and verify logs + adaptive update.
4. Skip/delay task and verify no duplicate/corrupt state.
5. Temporal Ops quota behavior with free vs premium.
6. SI console command valid/invalid handling.
7. Reflect/ChronoLogs rendering and filter/search.
8. Settings save + subscription visibility + legal links.

## Section 8: Persistence + Data Integrity

### Commands (adapt to your persistence files)
```powershell
flutter test test/unit/persistence_test.dart
flutter test test/unit/app_state_test.dart
```

### Pass criteria
- Empty, valid, partial, and malformed snapshots are handled safely.
- Task lifecycle state persists across restart.
- Trial/subscription state survives restart or safe revalidation.
- No private secret leakage into logs/snapshots.

## Section 9: Minimum Test Suite Buildout

### Priority targets
- Unit: app state lifecycle, SI ranking, persistence encoding/decoding/migration.
- Widget: Nexus, Smart Coach, Settings/Paywall.
- Integration: launch, task lifecycle, navigation back behaviors.
- E2E: human-like tap/type/scroll, permission dialogs.

### Commands
```powershell
flutter test test/unit
flutter test test/widget
flutter test integration_test
```

## Evidence Template
Copy this block into notes for each section.

```text
Section:
Date/Time:
Command(s):
Result: PASS | FAIL | BLOCKED
Evidence:
Issue/Ticket:
Retest:
```

## Final Go/No-Go Rule
- Go only if all release-blocking sections are PASS or have signed exception.
- Any FAIL in navigation/back, persistence corruption, or build gate is NO-GO.
