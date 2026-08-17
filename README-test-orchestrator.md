# One-command Flutter test orchestrator

`run-all-tests.ps1` runs the available checks back to back and stops at the first required failure:

1. `flutter pub get`
2. `flutter test` (unit and widget tests)
3. `flutter test integration_test` when `integration_test/` exists
4. `maestro test maestro` when the Maestro CLI and `maestro/` exist
5. `flutter devices` as a simulator/device smoke check
6. Device-targeted integration tests when `deviceId` is not `auto`
7. A bounded Android `adb shell monkey` run

## Setup

Copy these two files into the Flutter project root, then edit `test-orchestrator.json`:

- Set `monkey.package` to the Android application ID from `android/app/build.gradle`, `build.gradle.kts`, or `AndroidManifest.xml`.
- Set `deviceId` to an emulator/device ID for targeted tests, or leave it `auto` to use Flutter's default device.
- Keep `events` bounded. The default is 500 events.

Run from the project root:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\run-all-tests.ps1
```

Because monkey testing generates input on a connected Android device, it requires an explicit safety flag:

```powershell
.\run-all-tests.ps1 -AllowConnectedDevice
```

Useful controls:

```powershell
.\run-all-tests.ps1 -SkipMonkey
.\run-all-tests.ps1 -SkipMaestro
.\run-all-tests.ps1 -SkipSimulator
.\run-all-tests.ps1 -KeepGoing
```

Each run writes a timestamped transcript to `test-results\orchestrator-YYYYMMDD-HHmmss\run.log` and returns exit code `1` if any executed stage fails. Missing optional directories/tools are reported as skipped; required tools (`flutter` and `dart`) stop the run when absent.

This is a runner, not a substitute for real device coverage: start the desired emulator before running, install/debug-launch the app as required by your Maestro flows, and add project-specific smoke commands to the script if your app needs seeded data or a special build flavor.
