# ChronoSpark Strict Engineering Rules

These rules are mandatory for release readiness and are enforced by scripts and hooks.

## 1) Gate Commands (Required)

Run all commands from repository root:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/strict_gate.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/strict_gate.ps1 -IncludeAndroidRuntime`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/strict_gate.ps1 -IncludeAndroidRuntime -RequireAndroidDevice`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/strict_gate.ps1 -IncludeCoverage`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release_guard.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/coverage_guard.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/critical_coverage_report.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File check_architecture.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/strict_android_runtime_gate.ps1`

`strict_gate.ps1` is the source-of-truth umbrella gate and must pass before push/release.
`strict_gate.ps1 -IncludeAndroidRuntime` enables runtime/device checks as part of the same gate.
`strict_gate.ps1 -IncludeAndroidRuntime -RequireAndroidDevice` makes missing device a hard failure.
`strict_gate.ps1 -IncludeCoverage` runs tests with coverage output and enforces coverage thresholds.
`strict_android_runtime_gate.ps1` is the runtime/device gate. It auto-runs when a device is present and blocks on app-specific fatal runtime markers.

## 2) Crash and Error Capture

- `lib/main.dart` must keep all three handlers:
  - `runZonedGuarded(...)`
  - `FlutterError.onError = ...`
  - `PlatformDispatcher.instance.onError = ...`
- Any regression removing one of these handlers is a release blocker.

## 3) Android Security and Play Compliance Floors

- `android/app/src/main/AndroidManifest.xml` application tag must include:
  - `android:usesCleartextTraffic="false"`
- Android permission set is allowlisted and checked in `scripts/release_guard.ps1`.
- `android/app/build.gradle.kts` must keep:
  - compile SDK floor >= 34
  - target SDK floor >= 34
  - Firebase Crashlytics plugin
  - Google services plugin

## 4) Architecture and Layering

- `check_architecture.ps1` is mandatory and blocking.
- Feature UI must not bypass state/app boundaries.
- New services/providers must follow established ownership docs and rules.

## 5) Data Integrity and Security

- Account deletion requires secure backend endpoint configuration and must not clear local state before confirmed server success.
- Release endpoint env values must be valid HTTPS URLs.
- No mock bypass flags may be enabled for production builds.

## 6) Testing and Stability Readiness

- `flutter analyze` must pass with zero errors.
- `flutter test` must pass with zero failures.
- New critical paths (auth deletion, permissions, startup, SI routing) require focused tests.
- Coverage floors are enforced by `scripts/coverage_guard.ps1`.
- Initial enforced thresholds:
  - overall coverage >= 37%
  - `lib/data/services/auth_service.dart` >= 90%
  - `lib/data/services/backup_service.dart` >= 95%
  - `lib/data/repositories/google_play_paywall_repository.dart` >= 88%
  - `lib/data/services/sync_service.dart` >= 95%
  - `lib/core/debug/runtime_diagnostics.dart` >= 94%
- Layer minimums enforced by `scripts/coverage_guard.ps1`:
  - `domain/usecases` >= 85% (target 85-95%)
  - `domain/policies` >= 90% (target 90%+)
  - `domain/value_objects` >= 90% (target 90%+)
  - `data/repositories` >= 75% (target 75-85%)
  - `data/storage` >= 80% (target 80-90%)
  - `state/controllers/providers` >= 70% (target 70-85%)
  - `engine/si` >= 70% (target 70-85% meaningful)
  - `features/ui` >= 50% (target 50-70% focused)
- Integration flow gate:
  - at least 5 integration tests must exist under `integration_test/`
  - 5-8 critical integration flows should be treated as required release gates; additional integration tests should not replace unit/domain coverage growth
- `scripts/coverage_guard.ps1` also reports critical-only coverage across enforced files so release decisions are not distorted by low-value legacy/global noise.
- `scripts/coverage_guard.ps1` fails if any critical source file is missing its required companion test file.
- `scripts/critical_coverage_report.ps1` prints uncovered lines only for critical files so follow-up test work stays targeted.
- Removed or dead legacy surfaces must not be promoted to critical targets just to chase report noise.

## 7) Logging and Analytics Discipline

- Runtime diagnostics must remain active for startup and crash flows.
- Crashlytics and analytics must remain enabled in production env unless formally waived.

## 8) Hook Enforcement

- `.githooks/pre-commit`: runs release guard with `-NoProfile -ExecutionPolicy Bypass`.
- `.githooks/pre-push`: runs strict gate with `-NoProfile -ExecutionPolicy Bypass`.
- Activate hooks with:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install_git_hooks.ps1`

## 9) Device Diagnostics

- For runtime issues, use:
  - `android-diagnose-one-click`
  - `android-logcat-scan-latest`
- For strict runtime enforcement, use:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/strict_android_runtime_gate.ps1`
  - Add `-RequireDevice` when CI or release rehearsal must fail without a connected device.

## 10) Non-Negotiable Blocking Criteria

Any of the following blocks release:

- Strict gate failure
- Architecture check failure
- Missing crash handler wiring
- Cleartext traffic enabled
- Unexpected Android permissions
- Analyzer/test failures
- Unverified runtime diagnostics when crash reports are open
