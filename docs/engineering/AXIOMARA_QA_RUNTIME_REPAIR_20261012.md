# Isolated QA runtime repair

The Android Release run 38278678499 stopped before device execution: its QA
profile selected flavor `qa` but omitted `CHRONOSPARK_BACKEND_MODE=local`.
Gradle rejected that combination using the existing isolation guard.

The corrected debug profile explicitly uses local storage and disables mock
login, mock mode, tester entitlement and paywall bypass. Its assistant policy
matches the existing reviewed local public policy. Cloud services, purchases,
telemetry and external inference remain disabled in this QA lane.

The Maestro runner targets `com.ghostheart5.chronospark.qa` and copies complete
flow dependency trees into its evidence directory. Only package headers and
disclosed UTF-8/header normalization change in the copies; source files remain
unchanged. Per-file source and prepared hashes accompany the runtime evidence.
Wrong explicit packages and missing, wrong or duplicate flow app IDs fail closed.

Authentication recognizes local profile creation/reopening, completes setup
without creating a task, and waits for guide dismissal before feature navigation.
Creator automation uses the current `CONFIRM SELECTED` action, observes the
saved receipt and explicitly opens Timeline before persisted task readback.

Local validation: 30 focused Flutter environment/profile/backend tests, 101
workflow contract tests and 5 Python flow-preparation tests passed. Maestro
validation checked 30 files; the GitHub workflow validator checked 15 workflows.
Actual APK compilation and hosted UI execution must establish their own results.

This repair does not establish production subscription or external-AI acceptance.
Legacy tester APK/AAB scripts requesting release QA builds remain rejected by
the existing debug-only isolation guard. The separate native 16 KB lane still
needs package alignment before it can claim isolated-QA execution. Neither
limitation is bypassed or treated as successful smoke coverage.
