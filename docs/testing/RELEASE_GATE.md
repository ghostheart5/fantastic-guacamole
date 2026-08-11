# Release gate

Date: 2026-08-11
Scope: Phase 6 device integration and Patrol requirements

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
