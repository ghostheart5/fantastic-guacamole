# ChronoSpark test orchestrator

`run-all-tests.ps1` coordinates the repository's complete local validation gate on a disposable emulator in this order:

1. Dependency resolution.
2. Non-writing format verification.
3. Both secret guards.
4. Flutter analysis with fatal infos.
5. Maestro static contract validation.
6. Supabase Edge Function checks and tests.
7. Robot tests with coverage and the coverage ratchet.
8. Flutter application-root integration tests on the configured emulator.
9. The eleven-flow `qa-journeys` Maestro suite with source, APK, device, JUnit, explicit execution order and Logcat evidence.
10. Five bounded Android monkey variants against the exact QA APK installed by Maestro.

The checked-in configuration targets `emulator-5554`, Android API 35, and application ID `com.ghostheart5.chronospark`. Change the serial only when an explicitly approved disposable emulator is selected. When integration testing is selected, the orchestrator rejects a non-emulator serial during initial configuration validation, before running stages or installing an integration test. The native Planner learning test independently checks that its Android target is not a physical device before clearing preferences. The monkey matrix also refuses physical devices and caps every variant at 1,000 events.

QA journeys require a QA build and an emulator target. They install the test APK and reset its local app data; never point this gate at a personal installation. Maestro and monkey automation run serially against the same retained QA APK. The configured monkey matrix covers smoke, balanced, navigation, touch/motion and lifecycle: 1,700 total events across fixed seeds, with complete logs and successful relaunch checks required.

Run the complete configured gate from the project root:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\run-all-tests.ps1 -AllowConnectedDevice
```

The source snapshot must be clean by default. `-AllowDirtyTree` is available only for an intentional diagnostic run; evidence records the commit and dirty-entry count.

Optional controls:

```powershell
.\run-all-tests.ps1 -SkipMonkey
.\run-all-tests.ps1 -SkipMaestro
.\run-all-tests.ps1 -SkipSimulator
.\run-all-tests.ps1 -KeepGoing
.\run-all-tests.ps1 -PreflightOnly -AllowDirtyTree
```

Skipped, unavailable, or unauthorized stages are recorded as `not-run`. A run with any `not-run` stage exits with code `2` and reports `PARTIAL`; it is never reported as a successful complete gate. Executed failures exit with code `1`. Only a run in which every configured stage executes and passes exits with code `0`.

Each orchestrator run writes a transcript under `test-results/orchestrator-<timestamp>/`. Maestro writes evidence under `artifacts/maestro/`, and the monkey matrix writes its fixed seeds, event mixes, APK hash, crash/ANR scan, and relaunch result under `artifacts/monkey/`.

The eleven Maestro cases cover Planner, Creator, SI, Timeline, Progression, required tester Settings controls, subscription containment, tester logout, A → B → A isolation, the learned lifecycle and its immediate restart readback. The runner generates `executionOrder` configuration and passes it to Maestro through `--config`; it stops the remaining sequence after a flow failure. The lifecycle must immediately precede readback, with no intervening clear-state flow, reset or identity change. Do not replace this suite with an alphabetically discovered folder run. See [the Maestro suite documentation](.maestro/README.md) for exact paths and standalone commands.

Maestro UI assertions alone cannot make a stage pass. The evidence gate requires a nonzero, complete, failure-free JUnit result matching all selected flows; complete Logcat capture; and zero configured Flutter/framework, fatal or ANR markers. A passing UI journey with runtime errors is a failure. Interrupted capture, missing results and skips remain failures or partial evidence, never an all-pass certificate.

The generic learning-ledger row proves restart readback of a completed outcome. Task identity is verified separately by [the Planner learning persistence integration regression](integration_test/planner_learning_identity_test.dart), which checks the actual Planner-created task and its persisted outcome by `subjectId` after storage reopening. The earlier seed task must not satisfy that assertion.

The subscription case verifies that commerce remains contained. It does not exercise Google Play purchase/restore, entitlement changes or simulated billing. Credential-backed login, signup and full onboarding are outside the QA journey set. Run those separately with disposable accounts and compatible builds through the dedicated evidence runner. Destructive account deletion remains outside the ordinary orchestrator and requires its separate confirmation contract. These local gates do not replace verification of the final signed AAB, installed Play version, real-account cohort or physical-phone response journeys.

The standalone Maestro runner still defaults to five-flow `qa-smoke`; the hosted Maestro workflow also selects that smaller suite. Only an explicit `qa-journeys` selection, including the selection made by `run-all-tests.ps1`, represents the eleven-flow journey gate.
