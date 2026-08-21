# ChronoSpark test orchestrator

`run-all-tests.ps1` coordinates the repository's non-destructive release gate in this order:

1. Dependency resolution.
2. Non-writing format verification.
3. Both secret guards.
4. Flutter analysis with fatal infos.
5. Maestro static contract validation.
6. Supabase Edge Function checks and tests.
7. Robot tests with coverage and the coverage ratchet.
8. Flutter application-root integration tests on the configured emulator.
9. The five-flow QA Maestro smoke suite with commit, APK, device, and Logcat evidence.
10. Five bounded Android monkey variants against the exact QA APK installed by Maestro.

The checked-in configuration targets `emulator-5554`, Android API 35, and application ID `com.ghostheart5.chronospark`. Change the serial only when an explicitly approved disposable emulator is selected. The monkey matrix refuses physical devices and caps every variant at 1,000 events.

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

Credential-backed login and signup journeys are not part of the mock QA smoke set. Run them only with disposable account credentials through the dedicated Maestro evidence runner. Destructive account deletion is always outside the ordinary orchestrator and requires its separate confirmation contract.
