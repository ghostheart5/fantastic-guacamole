# Release gate

Date: 2026-08-11
Scope: Phase 8 backend, staging, authorization, and data-isolation requirements

## Device gate

The Android device gate is **blocked** until all required Patrol targets pass
against the exact candidate binary and commit. It is never satisfied by a
synthetic widget tree, a skipped target, an optional assertion, a production
account, or a production service.

Run only on a dedicated Android 10/API 29+ emulator or physical test device
with Android platform-tools (`adb`) and Patrol installed. The sole runner is:

```powershell
./tool/run_patrol_device_tests.ps1 -DeviceId <adb-device-id> -RunId <unique-id>
```

The runner builds/runs the nonproduction `maestro` profile and clears only
`com.ghostheart5.chronospark.maestro`. It passes mock-login, mock-mode, and
cloud-sync-disabled defines, so it must not contact a production account or
production backend. It emits device model/API metadata, logcat, and a final
screenshot under `artifacts/device-e2e/`; Patrol output remains in the runner
log and failed captures are not approved visual baselines. The runner disables
Patrol CLI analytics for the test process.

## Required passing journeys

1. Cold application launch completes onboarding and reaches the authentication
   gate.
2. Mock-only authentication reaches Nexus; background then foreground preserves
   the real app root.
3. Creator saves an isolated deterministic task; Timeline displays that exact
   task; Settings writes dark mode; the verified application link reaches
   Timeline; logout then login returns to the real root.
4. The runner force-stops the test package. The next real-root launch proves
   the deterministic task and dark-mode setting persisted.
5. The runner revokes notification permission from only the test package; the
   real Settings screen must display the native permission request and denied
   recovery state.
6. The runner disables then restores only the selected device network radios;
   the real offline banner must appear and then clear.

Every journey has bounded condition waits and mandatory control assertions. A
missing control is a failure. The device OS/model and artifact location must be
attached to the candidate release evidence.

## Current blockers

- The isolated `emulator-5554` Android 17/API 37 emulator is available and the
  runner can resolve `adb` through `ANDROID_HOME`; compatible Patrol CLI 3.11.0
  is installed. The corrected runner started but reached no test result within
  the 124-second bounded command deadline. The new Patrol tests are not marked
  passed.
- Controlled session expiry still requires an approved isolated fixture. No such
  fixture is present today; using live services or production accounts is
  prohibited.
- HTTPS deep-link execution requires the candidate `.maestro` application to
  be associated with the verified host on the selected test device. A failed
  association is a device-gate failure, not an optional alternate path.

Until these blockers are resolved and the required runs are green for the exact
candidate, device integration remains a release veto.

## Phase 7 Maestro release gate

The Maestro release gate has four distinct execution levels. They are not
interchangeable and none may silently fall back to an optional assertion:

| Level | Command | Required evidence |
|---|---|---|
| PR smoke | `pwsh ./scripts/run_maestro.ps1 -Profile maestro -Level pr-smoke` | APK package-ID match, reset isolated package, passing JUnit and artifacts |
| Nightly feature E2E | `pwsh ./scripts/run_maestro.ps1 -Profile maestro -Level nightly-feature-e2e` | All feature suites, regression isolation, debug artifact bundle |
| Pre-release full | `pwsh ./scripts/run_maestro.ps1 -Profile maestro-onboarding -Level pre-release-full` | Onboarding plus Nexus, Creator, Timeline, Smart Planner, SI Console, Trajectory, Progression, Profile, Settings, notifications, and regressions |
| Sandbox subscriptions | `pwsh ./scripts/run_maestro.ps1 -Profile maestro -Level sandbox-subscriptions` | Isolated sandbox account/store configuration and all required billing controls |

The runner supplies `APP_ID` from its actual selected build profile and rejects
an APK whose package ID differs. It resets only
`com.ghostheart5.chronospark.maestro`; staging and production accounts are not
valid targets for these isolated levels. A failed Maestro process is a failed
gate even if a partial JUnit file appears clean. Maestro debug output, device
logcat, and device screenshots are failure diagnostics—not visual baselines.

The pre-release gate is blocked until all four levels pass for the exact
candidate binary, with screenshots/logs retained for human review. The
subscription level remains blocked until a sandbox store account is explicitly
available; it must never be recorded as a skipped or optional pass.

## Phase 8 backend release gate

Backend authorization is a release veto until all required current-head local
and approved-staging evidence is attached. Historical staging transcripts,
static source inspection, pending cases, skipped cases, or an unconfirmed host
cannot satisfy this gate.

### Required safety preconditions

1. Run the offline gate first:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\staging_validation\phase8_backend_harness_test.ps1
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\staging_validation\run_phase8_backend_tests.ps1
   ```

2. Positively identify the approved target as exactly
   `https://pxtjkwfedrtnxuihtdox.supabase.co`; the URL must be HTTPS, have no
   path/query/fragment, and match case-sensitively. The explicit confirmation
   switch remains required.
3. Use only isolated User A, User B, anonymous, and normal-authenticated actors.
   A privileged server role is allowed only in a separately approved server-side
   fixture path and is never supplied to client tests.
4. Give every live run a unique Phase 8 run ID. Create only run-owned records or
   objects, restrict cleanup to exact run-owned identifiers, verify cleanup, and
   reject wildcard/broad deletion.
5. Do not reset a database, deploy/apply/repair a migration, deploy a function,
   use production fallback, or log raw credentials, JWTs, requests, exceptions,
   memory, receipts, or response bodies.

### Required evidence

- Local pgTAP: schema compatibility, migrations, RLS, spoofed ownership,
  privileges, profile/metrics, rate limits, credits, and deletion cascades.
- Local Deno: session freshness, malformed deletion input, Google OIDC caller
  validation, retired endpoints, and purchase/subscription validation.
- Confirmed staging: authentication refresh/expiry, two-user read/write
  isolation, spoof denial, privileged RPC denial, profile repair, global metrics,
  rate limits, storage isolation, synchronization, deployed Edge Function
  malformed/unauthorized behavior, monetization isolation, and deletion
  boundaries.
- Approved sandbox: purchase verification and restore with test receipts and
  bounded cleanup; never a production purchase or account.

### Current Phase 8 verdict

**BLOCKED.** The offline guard harness passed 12 assertions, selected Deno tests
passed 17/17, and static manifest/PowerShell/SQL wrapper validation passed. The
drift-manifest test fails on source-hash mismatches for `ai-proxy`,
`monetization-verify`, and `account-delete`. Supabase CLI and `psql` are absent,
so pgTAP was not executed. No staging/sandbox case was run because this phase did
not receive a fresh explicit environment/mutation approval. Those cases are
pending, not passing.

## Phase 10 fuzz, Monkey, and chaos release gate

Phase 10 local deterministic tests are a release-supporting layer only. They
must not contact a remote environment and cannot satisfy the Android/device
resilience gate by themselves.

- PR smoke requires an explicitly approved isolated APK/device Monkey run of
  1,000 events for each selected seed.
- Nightly requires 10,000 events for each configured nightly seed.
- Pre-release requires 50,000 to 100,000 events for each configured
  pre-release seed and distribution.
- The runner must derive the application ID from the inspected APK and reject
  a package that is not an isolated maestro, staging, debug, or test package.
- Evidence must include binary SHA-256, seed, count, distribution, device/OS,
  crash, ANR, native-crash, dropped-event, and final-state records.
- A failed run creates an exact replay command. It may not be silently retried
  or converted into a skipped pass.

This gate is currently BLOCKED: no current candidate APK/device campaign was
authorized or executed in Phase 10.

Phase 10 static validation passed for the Monkey runner PowerShell syntax and
profile distributions. The targeted local Flutter command produced no result
within its 60-second bounded window and is unexecuted; it is not release
evidence.

## Phase 11 performance and soak release gate

Phase 11 is **BLOCKED** until the exact nonproduction candidate binary has
candidate-identifying performance evidence. The local measurement contract and
profile validator are useful only to validate the harness; they are not startup,
frame, memory, network, database, or soak evidence.

### Required evidence by execution level

| Level | Required measurement | Gate status |
|---|---|---|
| PR | Deterministic local contract and pure-workload checks | Supports change review only |
| Nightly | Isolated emulator warm startup, Nexus, Creator, Timeline, Trajectory, Progression, sync, notifications, and timeout measurements | Pending |
| Physical-device release | Signed isolated candidate cold/warm startup, rendering, Timeline heavy-list scroll/search, memory, frame-jank, migration, recovery, and notification evidence | Blocking / pending |
| Soak | Several-hour isolated candidate scenario with repeated lifecycle, sync, offline recovery, scrolling, and notifications | Blocking / pending |

Every measurement requires commit SHA, binary SHA-256, device, OS, build mode,
dataset, method, warm-up policy, sample count, median, p95, threshold, and
regression percentage. Proposed thresholds in the Phase 11 profile are
unvalidated planning values, not approved baselines. Device, candidate, backend,
and production-targeted work is not launched by the local runner.

The performance gate fails when a required result lacks identity/evidence, a
reviewed threshold is exceeded, a soak run has crash/ANR/lost final state, or
memory/frame regression is unexplained. Pending and unexecuted cases cannot be
recorded as passing.

Phase 11 local profile validation passed. The targeted Flutter Phase 11 command
did not initialize or emit output within its 60-second bounded window, so its
Dart tests are unexecuted and provide no release evidence.

## Phase 12 flaky-test and regression-governance gate

The release gate rejects a critical failure even when a subsequent retry passes;
the first failure and its artifact remain visible. Automatic retries may collect
evidence only. A quarantined test requires a named owner, linked defect,
replacement coverage, reviewer, and unexpired date. An expired quarantine,
unreviewed skipped test, unknown conditional execution path, or permanent
non-blocking exception blocks release.

Changed-file selection is permitted only for PR efficiency and always retains
release and behavior guards. It never reduces nightly or pre-release execution:
the pre-release selector returns the complete `test` suite, followed by the
already-required device, backend, human, performance, and soak gates.

No active Phase 12 flake, quarantine, or duplicate-deletion proposal exists at
this commit. That absence is not permission to remove tests automatically.

Phase 12 PowerShell governance validation passed. The targeted Flutter
governance contract command did not initialize or emit output within its
60-second bounded window and is unexecuted, not passing release evidence.
