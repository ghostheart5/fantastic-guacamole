# ChronoSpark test ledger

Date: 2026-08-11
Scope: Phase 9 Advanced Human Root Testing (Phase 8 evidence retained below)
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

## Phase 7 Maestro E2E foundation and coverage

### Flow dependency map

`isolated .maestro build -> package-ID verification -> package reset -> app
launch/onboarding -> mock authentication -> Nexus -> Creator / Timeline /
Smart Planner / SI Console / Trajectory / Progression / Profile / Settings ->
notifications, sandbox subscriptions, and regression chains -> mandatory final
assertion -> JUnit + Maestro debug + logcat + screenshot artifacts`.

Creation is owned solely by the `maestro/creator` suite: task, goal, routine,
and note. Smart Planner is guidance and SI Console is explanatory; their
separate suites are joined only by a UI-isolation regression check and neither
one is connected to a chat feature.

### Phase 7 dispositions

| Area | Evidence after Phase 7 | Remaining gap / owner | Blocking status | Runtime |
|---|---|---|---|---|
| App identity and reset | `run_maestro.ps1` resolves the selected actual test build ID, validates APK badging, and clears only the isolated package unless explicitly retained | Runner requires connected Android device; Test Infrastructure | Blocking for device evidence | Build + 1–5 min |
| PR smoke | launch, auth, Nexus, Timeline, Creator input guard | Candidate-device run required; Release Engineering | Blocking until run | <5 min |
| Feature E2E | authentication, onboarding, Nexus, Creator, Timeline, Smart Planner, SI Console, Trajectory, Progression, Profile, Settings, notifications, subscriptions, regression | Sandbox billing/store implementation must be configured; Monetization | Amber | 15–30 min |
| Creator | canonical task, goal, routine, note creation flows use Creator selectors | End-to-end persistence/duplicate lifecycle remains Patrol/integration owner | Amber | 3–6 min |
| Smart Planner / SI Console | separate suites plus visible draft/guide isolation regression | This does not validate memory retention or model correctness; Phase 7 intelligence owner | Amber | 2–5 min |
| Trajectory / Progression | new arrival suites and release inclusion | Scenario correctness remains runtime/provider coverage | Amber | <2 min |
| Notifications | open plus explicit empty-or-list alternate assertion | OS permission denial stays device/Patrol coverage | Amber | <2 min |
| Subscriptions | sandbox-only selection, restore, free-plan, and persistence probes with mandatory controls | Store purchase completion needs an isolated sandbox account; Monetization | Blocking for subscription release gate | 5–10 min |
| Release guard | full suite includes onboarding, Nexus, Creator, Timeline, Smart Planner, SI Console, Trajectory, Progression, Profile, Settings, notifications, regression; subscriptions are a separately required sandbox gate | Needs candidate run and human artifact review; Release Engineering | Blocking | 30–45 min |

### Removed false-green and disconnected coverage

- Removed all 33 `optional: true` usages from the Maestro tree. Critical
  navigation, actions, and terminal assertions now fail when absent.
- Removed generic `planner` creation terminology and moved those flows under
  `maestro/creator`; Smart Planner remains a distinct surface name.
- Repaired the release-suite disconnect by adding onboarding, Nexus, Creator,
  Trajectory, Progression, and regression chains. Subscriptions are not folded
  into a normal candidate run: the separate sandbox level makes its external
  prerequisite visible.
- Settings restart coverage now asserts only a verified re-entry to the real
  Settings surface. The previous toggle assertions depended on a Flutter key,
  not an accessible Maestro identifier, so asserting persisted preference
  state would be false evidence without a separately approved semantic ID.
- Notification-denied recovery remains a required real-device/Patrol path;
  the Maestro feature suite covers ordinary notification arrival/list states
  without pretending a non-denied device is in the recovery state.
- The runner no longer accepts a zero-failure JUnit file after a nonzero
  Maestro process exit. Artifacts are diagnostic outputs, never baselines.

### Phase 7 validation record

- Static flow check: passed. Every YAML flow has `appId: ${APP_ID}` and every
  `runFlow` target resolves to a file in the tree.
- Runner syntax check: passed through the PowerShell parser.
- Maestro CLI syntax check: unexecuted. The globally installed `maestro.cmd`
  points to a missing temporary installation, so `maestro test --help` fails
  before command parsing.
- Smallest device command attempted:
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\run_maestro.ps1 -Profile maestro -Level pr-smoke -Device emulator-5554`.
  The isolated Android 17/API 37 emulator was connected, but the build/runner
  produced no result within the bounded 60-second command window. It was
  stopped and is **unexecuted**, not passed or failed.

## Phase 8 backend and staging coverage

Phase 8 adds an offline-first manifest and guard harness around the existing
Supabase assets. The manifest covers all 21 requested areas and distinguishes
local evidence from staging or sandbox evidence. A staging case remains
`pending-*` until it is rerun against the current commit after explicit approval;
historical transcripts are not current-head passing evidence.

### Inventory and disposition

| Layer | Current assets | Phase 8 result | Blocking gap |
|---|---:|---|---|
| pgTAP SQL | 8 transaction-wrapped files | Static transaction/plan validation passed; one unconditional placeholder test was replaced with real profile-trigger/search-path/privilege assertions | Supabase CLI and `psql` unavailable, so 0 SQL tests executed |
| Deno | 7 test files total, including the isolated AI-proxy test and drift verifier | 17 tests from 5 selected non-chat files passed locally with no network permission | Drift verifier failed on current source-hash mismatches for `ai-proxy`, `monetization-verify`, and `account-delete` |
| PowerShell staging | 31 files after Phase 8 | All files parsed; 12 offline target/refusal/redaction/run-ownership assertions passed | No live runner was invoked; current-head staging evidence is pending |
| Staging case manifest | 21 required areas | All areas and referenced assets validated | Staging/sandbox cases stay pending until approved hostname, actors, fixtures, and cleanup are confirmed |

### Area status

| Area | Existing/new evidence | Current status |
|---|---|---|
| Authentication; refresh/expiry | guarded User A/User B login helpers; recent-sign-in Deno boundary tests | Local boundary tests passed; live Auth refresh/expiry pending staging |
| Two-user isolation; spoofed IDs; unauthorized reads/writes | core-sync pgTAP and guarded User A/User B PowerShell suites | Static validation passed; live RLS mutations pending staging approval |
| Privileged RPC; profile repair; global metrics | SQL privilege checks and guarded denial/repair suites | Catalog contracts ready; live caller behavior pending staging |
| Rate limiting | AI/monetization pgTAP and two-session runner | SQL unexecuted and live counter mutations pending staging |
| Storage isolation | path-scoped guarded runner | Pending exact bucket/policy approval and staging mutation approval |
| Synchronization | task/goal/habit/settings/user-metrics RLS assets | Pending staging execution with run-owned fixtures |
| Schema compatibility; migrations | hosted-schema/function-privilege pgTAP and drift verifier | SQL pending local CLI; drift verifier currently failing |
| Edge Functions; malformed requests | mocked Google OIDC validation, deletion input validation, retired endpoint, and subscription validation | 17 selected Deno tests passed; no deployed function called |
| Credits; purchase verification; entitlement isolation; restore | credit/RPC pgTAP, denial runners, read-isolation assets, deterministic subscription verification | Pure verification passed; sandbox receipt and all staging writes pending |
| Account deletion boundaries | deletion input/recent-sign-in Deno and cascade pgTAP | Local Deno passed; cascade SQL and destructive staging boundary test pending |

### Phase 8 safety contract

- The only approved staging hostname encoded by the harness is
  `pxtjkwfedrtnxuihtdox.supabase.co`; confirmation is still mandatory and no
  caller may substitute another host.
- Client staging helpers reject service-role/secret-key environment variables.
- Test run IDs are unique and cleanup identifiers must contain the exact run ID;
  wildcard and unrelated cleanup targets are refused.
- Diagnostics redact bearer tokens, JWTs, passwords, API keys, and secrets;
  RPC failures log stable status/category data rather than raw bodies/exceptions.
- The Phase 8 runner contains no database push/reset, migration apply/deploy,
  Edge Function deploy, production fallback, or network operation.

### Phase 8 validation record

- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File
  .\tool\staging_validation\phase8_backend_harness_test.ps1`: 12 passed, 0
  failed.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File
  .\tool\staging_validation\run_phase8_backend_tests.ps1`: manifest, 31
  PowerShell files, and 8 SQL transaction wrappers passed static validation.
- Selected Deno backend tests: 17 passed, 0 failed, with no network permission.
- `deno test --allow-read=supabase
  supabase/drift/verify_manifest_test.ts`: 0 passed, 1 failed because three
  existing function source hashes do not match the hosted-state manifest.
- Staging/sandbox: 0 executed, all pending. No environment file was imported,
  no remote host was contacted, and no mutation or cleanup occurred.
- Local pgTAP: 0 executed because Supabase CLI and `psql` are unavailable.

No production, migration, schema, deployment, credential, UI, or chat file was
changed by Phase 8.

## Phase 9 Advanced Human Root Testing

Phase 9 adds a versioned, black-box Human Root Testing system for exact release
candidates. It is documentation and governed templates only: **zero human cases
have been executed and zero human results are claimed**.

| Coverage class | Phase 9 evidence | Current status | Primary owner |
|---|---|---|---|
| Human/UAT | 17 versioned case definitions, canonical core journey, root, interruption, persona and dataset procedures | Defined; all cases NOT RUN | Release Engineering / Human QA |
| Accessibility | Human all-root checklist plus device matrix and evidence requirements | Defined; NOT RUN | Accessibility owner |
| Release guard | Candidate passport, severity/veto rules, retest/independent-verification and sign-off templates | Defined; human release gate remains BLOCKED | Release Engineering |
| Backend/security | Persona and environment boundaries reference approved non-production only | No environment contacted; NOT RUN | Security / backend owner |

### Human Root release blockers

- No exact candidate passport has been completed with commit SHA, binary hash,
  flavor, backend, schema, device and evidence chain.
- HR-CORE-001 and all applicable persona/root/interruption/accessibility cases
  are NOT RUN; no human release decision can be inferred.
- Required independent verification is absent until a separate human execution
  phase records it.
- Automatic veto categories remain mandatory checks: data loss, cross-user
  data, auth bypass, duplicate payment/credits, irreversible incorrect state,
  crash loop, broken core journey, inaccessible primary action, account
  deletion failure, sensitive-data exposure, and unauthorized chat connection.

Phase 9 modified only docs/testing human-test governance and templates. It did
not execute tests or human cases and did not modify production, backend,
credentials, persistence, or chat code.

## Phase 10 property, fuzz, Monkey, and chaos testing

Phase 10 adds fixed-seed local property tests, an opt-in Android Monkey profile
and replay runner, and a documented fault-injection matrix. It adds no
production, chat, backend, credential, or UI change.

| Coverage class | Evidence | Status |
|---|---|---|
| Property/model behavior | Deterministic lifecycle/serialization, sync/fault, progression, and Trajectory tests | Local execution recorded separately; no device claim |
| Fuzz/chaos | Seed bank 260726/260801/260802/260803/704404 and profile definitions | Historical seeds are replay-only; no current Monkey run |
| Device Monkey | Explicit runner derives isolated app ID from APK and requires Execute switch | NOT RUN; release-blocking where required |
| Fault injection | Local queue-response/storage categories plus documented device/staging matrix | Local subset only; device/staging NOT RUN |

The Phase 10 gate remains blocked until an approved isolated binary/device run
captures evidence for the required Monkey level and any device-only chaos cases.

### Phase 10 validation record

- PowerShell parser validation for tool/chaos/run_phase10_monkey.ps1: passed.
- Monkey profile distribution validation: passed; every profile totals 100 and
  has system-key events disabled.
- Targeted local command flutter test test/phase10: stopped after 60 seconds
  with no runner output. It is unexecuted, not passing or failing.
- Android Monkey, device fault injection, staging fault injection, and any
  production target: not invoked.

## Phase 11 performance and soak testing

Phase 11 adds a test-only measurement contract, fixed dataset vocabulary,
provisional budget profile, and a local-safe profile validator. It does not
change production performance behavior or connect any chat surface.

| Coverage class | Evidence | Status | Primary owner |
|---|---|---|---|
| Local performance harness | Immutable measurement metadata, percentile/regression calculation, and a deterministic ordering/search workload | Available locally; not a candidate result | Test Infrastructure |
| Existing widget timing | Two in-process widget pump tests plus source lifecycle contract | Retained but weak/synthetic: missing frame timings are accepted and no candidate/device identity exists | UI owners |
| Startup/Nexus/Creator/Timeline | Provisional cold/warm, first-render, save/load/search/scroll budgets and datasets | Pending isolated candidate/device measurement | Release Engineering |
| Trajectory/Progression/sync/migration | Provisional calculation, backlog, and migration budgets | Pending isolated candidate/database fixture measurement | Domain and backend owners |
| Memory/jank/recovery/notifications | Provisional non-time budgets and evidence requirements | Pending physical-device measurement | Mobile platform owner |
| Smart Planner/SI Console timeout | Provisional timeout observation only; no prompt/model/chat change | Pending isolated candidate measurement | Intelligence owner |
| Soak | Required repeated lifecycle, sync, scrolling, notifications, offline recovery, and several-hour stability scenarios | Pending; never silently skipped | Release Engineering |

### Phase 11 execution record

- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File
  .\tool\performance\run_phase11_local_measurements.ps1 -Tier pr` passed.
  It validated JSON/profile structure only and neither launched an application
  nor established a device-performance baseline.
- `flutter test test/phase11 --concurrency=1` produced no runner output before
  its 60-second bounded command window elapsed. The Phase 11 Dart tests are
  unexecuted, not passing or failing; this is an environment warning.
- Emulator, physical-device, database migration, synchronization, notification,
  memory, frame-jank, and soak measurements are pending until an isolated
  candidate and measurement environment are approved.
- All thresholds in `tool/performance/phase11_budget_profiles.json` are
  explicitly provisional and unvalidated. A missing candidate metadata field is
  pending, not passing.
