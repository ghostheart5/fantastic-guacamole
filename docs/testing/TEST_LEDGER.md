# ChronoSpark test ledger

Date: 2026-08-11
Scope: Phase 6 real-application Android device integration and Patrol coverage
Source inventory: `ADVANCED_TEST_PLAN.md` (the four legacy ledger documents named
by the Phase 0 request are not present in this checkout).  `AGENTS.md` is present
but empty.

## Coverage inventory

| Feature | Existing evidence | Missing/weak evidence | Primary owner | Blocking | Future test | Priority | Approx. runtime |
|---|---|---|---|---|---|---|---|
| Nexus | `features/nexus/unit`, route integration | No runtime empty/loading/partial/error/offline or persistence matrix; route checks are structural | Nexus | Amber | Provider-backed widget state matrix and restart journey | P1 | <1s |
| Creator | mode unit, route integration, release/behavior contracts | No runtime create/validate/retry/idempotency matrix for all item kinds | Creator | Amber | Device-backed Creator-to-Timeline journey | P1 | <2s |
| Timeline | entity/unit and route integration | No runtime lifecycle matrix or provider failure/retry coverage | Timeline | Amber | Timeline widget with persisted projections and action recovery | P1 | <2s |
| Trajectory | deterministic unit fixtures and provider-overridden widget integration | Complete scenario coverage exists; empty/loading/partial/error/offline/stale semantics are missing | Trajectory | Amber | Snapshot-state widget matrix and scenario labeling | P1 | <2s |
| Progression | policy/unit and route integration | No repeated-award persistence or downstream aggregate behavior | Progression | Amber | Restart and reward idempotency integration | P1 | <1s |
| Profile | ProfileHeader/ProfileScreen widgets | Limited failure/loading/offline input and repeated navigation coverage | Profile | Amber | Auth/session lifecycle widget matrix | P1 | <2s |
| Settings | permission model/provider unit and screen tests | No persistence/retry/offline or max/Unicode input matrix | Settings | Amber | Platform permission and process-death coverage | P1 | <2s |
| Smart Planner | isolated input/output and structural prompt/release contracts | No network-free state/fallback/retry matrix; chat isolation must remain explicit | Smart Planner | Amber | Fake proxy and request-budget evaluation | P1 | <2s |
| SI Console | command/placeholder unit, context assembly, integration/contract tests | No complete source-state/retry/idempotency matrix; chat isolation must remain explicit | SI Console | Amber | Fake proxy grounded-response evaluation | P1 | <2s |

### Classification of current evidence

- Runtime unit behavior: domain entity, policy, provider, repository, and
  controller tests; the new Phase 4 matrix is the focused addition.
- Widget behavior: Profile and Trajectory widget tests; existing screen tests
  remain in place and are not deleted.
- Source/structural contract: `test/behavior`, `test/release`, navigation and
  source-inspection tests. These are drift guards, not runtime proof.
- Integration: feature integration tests and canonical in-process journeys.
- Device integration: `integration_test/` and Patrol assets; not run in Phase 4.
- Maestro/E2E: `maestro/`; not run in Phase 4.
- Backend/security: Supabase and staging assets; not run in Phase 4.
- Accessibility: dedicated accessibility/contract tests; not run in Phase 4.
- Performance: performance assets; not run in Phase 4.
- Fuzz/chaos: monkey/fuzz assets; not run in Phase 4.
- Human/UAT: governed human-root plan is documented, but no live UAT run is
  part of this phase.
- Release guard: workflow/release contract tests; not run in Phase 4.

## Phase 4 addition

Added `test/behavior/phase4_behavior_matrix_test.dart` as test-only coverage.
It uses deterministic timestamps, fixed IDs, real domain entities, a fake
provider/store with explicit empty/loading/success/partial/error/offline states,
and idempotent retry behavior. It covers Creator item construction and input
boundaries, Timeline validation/order/status, Nexus aggregate completeness,
Trajectory cold-start versus complete summaries, Progression boundaries,
Profile widget interaction, Settings permission state, and isolated Smart
Planner/SI Console local output behavior.

No production, persistence implementation, chat, endpoint, credential, or
workflow file was changed.

## Phase 4 validation record

- Targeted command: `flutter test test/behavior/phase4_behavior_matrix_test.dart`
- Result: timed out after 120 seconds in this environment before producing a
  test report. No full suite was run.
- A follow-up `dart test`/format attempt also did not produce output and was
  stopped; this is recorded as an environment warning, not a product failure.
- Pass/fail/skip counts: unavailable because the runner did not initialize.
- Warnings: Flutter/Dart test runner initialization timeout.

## P0 blockers carried forward

1. No current head-level release evidence until the repaired workflow executes.
2. Device/Maestro/backend/UAT layers remain disconnected from this unit/widget
   phase.
3. The existing worktree contains unrelated user changes; they were preserved
   and excluded from the Phase 4 change set.

## Phase 6 device and Patrol inventory

| Asset | Classification before Phase 6 | Phase 6 disposition | Coverage / remaining gap | Gate status |
|---|---|---|---|---|
| `integration_test/human_like_smoke_test.dart` | Real application boot, but conditional discovery and `pumpFor` timing make it false-green-prone | Retained as non-gating historical smoke evidence | Does not prove required controls or device lifecycle behavior | Non-blocking |
| `integration_test/patrol_smoke_test.dart` | Synthetic `MaterialApp` text harness | Replaced with the real `main()` root: cold launch, onboarding completion, and explicit authentication gate | Requires isolated Android device and mock-only configuration | Required, unexecuted |
| `integration_test/patrol_native_app_smoke_test.dart` | Conditional native root boot with hard skip | Replaced with real login, Nexus arrival, background/foreground, and mandatory final assertions | Warm launch only; process death is in the dedicated test | Required, unexecuted |
| `integration_test/patrol_application_journey_test.dart` | Absent | Added real Creator save, Timeline verification, settings write, verified-app-link navigation, logout/login, screenshots | Deep-link host verification must be present on the test device | Required, unexecuted |
| `integration_test/patrol_process_restart_test.dart` | Absent | Added process-restart verification of the saved task and persisted dark-mode setting | Runner force-stops the nonproduction `.maestro` application before this test | Required, unexecuted |
| `integration_test/patrol_permission_denied_test.dart` | Absent | Added real Android notification-denial and recovery-state journey | Runner revokes only `POST_NOTIFICATIONS` from the isolated test package | Required, unexecuted |
| `integration_test/patrol_offline_state_test.dart` | Absent | Added externally controlled offline interruption and recovery assertions against the real root | Runner disables then restores only selected device radios | Required, unexecuted |
| `tool/run_patrol_device_tests.ps1` | Absent | Added one-device, mock-only Android runner with package/OS metadata, logcat, final screenshot, bounded Patrol targets, and failure propagation | No iOS runner in this phase | Required on Android candidate |

### Device coverage classification

- Real application device integration: cold launch, onboarding, authentication
  gate, Nexus arrival, Creator save, Timeline verification, settings persistence,
  background/foreground, process restart, verified deep link, logout/login,
  denied notification permission, and offline interruption/recovery.
- Synthetic: none of the Phase 6 Patrol targets; each calls `main()` and asserts
  real navigation controls.
- Conditional: the legacy human-like smoke remains conditional and is explicitly
  non-gating. New Patrol targets fail configuration when their mandatory mock
  defines or deterministic fixture title are absent; they are never skipped.
- Not yet executable / release-blocking: controlled session expiry. The current
  application exposes no isolated device fixture that can expire an otherwise
  valid mock session without contacting a live service or relying on a
  production account. This is tracked as a Phase 6 follow-up requirement, not
  represented by a skipped or synthetic pass.

### Phase 6 execution record

- Android SDK/device discovery: `adb` is available through `ANDROID_HOME` and
  the isolated `emulator-5554` Android 17/API 37 emulator is connected. Patrol
  CLI is not installed/discoverable, so the runner stopped during preflight
  before clearing or launching the test package.
- Executed device tests: none. No device test is claimed to pass.
- Formatting attempt: the local Dart formatter did not initialize within the
  bounded command window and was stopped. This is an environment warning, not
  a test result.
- Runner attempt: Patrol CLI 4.6.1 was first rejected as incompatible with the
  app's Patrol 3.20.0 package; it was replaced with compatible Patrol CLI
  3.11.0. The corrected runner selected `emulator-5554` and started, but did
  not emit a test result before the 124-second bounded command deadline. It
  was stopped with only device metadata captured; this is neither a pass nor a
  product-test failure.
- Required isolated runner: `tool/run_patrol_device_tests.ps1` with exactly one
  Android 10/API 29+ emulator or USB-debuggable physical device, Patrol CLI,
  Android platform-tools, `CHRONOSPARK_BUILD_PROFILE=maestro`, and the runner's
  nonproduction mock/cloud-off defines. The runner uses
  `com.ghostheart5.chronospark.maestro`, records device model/API, clears only
  that test package, and writes artifacts under `artifacts/device-e2e/`.

## Phase 5 stop condition

The Phase 5 accessibility test exposed a confirmed production defect: the
back/settings controls in `lib/features/profile/ui/widgets/profile_header.dart`
are custom pressables without explicit semantic labels/roles. A compliant
TalkBack/VoiceOver assertion therefore requires a production accessibility
change. Per the Phase 5 instruction, implementation and validation stop here
pending owner approval for that production fix. No Phase 5 commit was made.
