# Axiomara notification first-date correction

This is a local runtime copy of `flutter_local_notifications` 22.3.0, taken from
the installed pub cache. The upstream package license is retained unchanged.
`UPSTREAM_MANIFEST.json` records SHA-256 hashes of all 99 copied upstream files
before this patch. The locked pub archive SHA-256 is
`1447ba911c60f2ba3f25dae1af151ec187162566b0f57e37771bf0b400f013ad`.
Upstream: https://github.com/MaikuB/flutter_local_notifications/tree/master/flutter_local_notifications

Copied runtime directories are `lib`, `android`, `ios`, and `macos`, plus the
original license, pubspec, README, and changelog. Upstream examples and Dart
tests are omitted; upstream native Android tests remain unchanged.

Only the Android component recurrence calculation changes. Previously it
reconstructed a candidate from today's date and the requested time, so a future
first date chosen to skip a completed day/week/month could be discarded. The
candidate now starts at the later of the real current time and the caller's
scheduled date. Existing component matching and indefinite recurrence remain.
The original private production method obtains the real system time and calls
a package-private deterministic overload used by focused native JUnit tests.
No public API, channel format, permission, alarm mode, Dart, iOS, or macOS change
is included in this patch.

`ComponentScheduleLowerBoundTest` calls the actual Java plugin implementation.
It covers future daily/weekly/monthly/yearly first dates, past-date catch-up,
equal deadlines, 400 successive daily periods, weekly/monthly repeats, and
07:30 local-time stability across Chicago spring/fall DST changes. It does not
claim behavior for a nonexistent or ambiguous local time within the DST switch,
nor actual Android delivery, reboot recovery, permissions, or battery modes.

Root owns dependency wiring and compiled-app/device verification. After wiring,
run the focused native test from the app Android project:

```powershell
.\gradlew.bat :flutter_local_notifications:testDebugUnitTest --tests com.dexterous.flutterlocalnotifications.ComponentScheduleLowerBoundTest
```

This file records source scope and validation instructions, not an execution
claim. Actual test results belong in the existing Axiomara retest report.
