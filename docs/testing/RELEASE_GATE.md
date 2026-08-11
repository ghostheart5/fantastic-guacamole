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
