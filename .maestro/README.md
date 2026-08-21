# Maestro E2E flows

End-to-end flows for ChronoSpark on Android. Twelve flows covering the paths
whose failure is invisible to the Dart test suite: real navigation, real Play
Billing surfaces, and the destructive account paths.

## Layout

```
.maestro/
  config.yaml            shared appId + selector notes (read before editing)
  flows/                 the twelve flows, numbered in execution order
  subflows/              shared steps: skip-onboarding, sign-in, open-from-nexus
```

## Running

Maestro is not a Dart dependency and is not installed by `flutter pub get`:

```bash
curl -Ls "https://get.maestro.mobile.dev" | bash
```

It needs a booted device or emulator and the app installed on it:

```bash
emulator -avd Pixel_9 &
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Credentials come from the environment so no test account is committed:

```bash
export MAESTRO_TEST_EMAIL=...        MAESTRO_TEST_PASSWORD=...
export MAESTRO_SIGNUP_EMAIL=...      MAESTRO_SIGNUP_PASSWORD=...
```

Then:

```bash
maestro test --exclude-tags destructive .maestro/flows   # safe full run
maestro test --include-tags critical .maestro/flows      # release gate
maestro test .maestro/flows/01-login.yaml                # one flow
```

## Source-paired Android evidence runner (Windows)

For a device result that can be traced to the exact checkout and APK, use the
PowerShell evidence runner instead of invoking Maestro directly. Its default
`qa-smoke` suite builds a QA-configured debug APK, installs it on one explicitly resolved
Android device, uses the tester-access login, runs product flows 04-08, captures Logcat during Maestro,
and writes a manifest containing the Git commit, dirty-tree count, APK SHA-256,
installed package version, device/API, flow list, timings, and exit status.

The QA profile deliberately bypasses onboarding so visual testing can open on
Nexus. Run flow 03 separately with a non-tester-access build when verifying the
two-page onboarding contract; counting it as QA smoke would report a false
failure without exercising onboarding.

```powershell
# Confirm tools, device, flow contracts, and output location. No build/install/run.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_maestro_android_evidence.ps1 -PreflightOnly

# Build, install, and run the current non-destructive QA smoke journeys.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_maestro_android_evidence.ps1

# Real-account safe suite. Set the four MAESTRO_* variables shown above first.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_maestro_android_evidence.ps1 -Suite safe -BuildProfile debug

# Run selected QA-compatible flows.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_maestro_android_evidence.ps1 -Suite custom -BuildProfile qa -Flow .maestro/flows/04-smart-planner.yaml,.maestro/flows/07-timeline.yaml
```

Evidence is written beneath `artifacts/maestro/`, which is Git-ignored. Logcat
is sanitized for known test credentials, email addresses, bearer tokens, JWTs,
and credential-shaped fields; the raw capture is deleted unless
`-KeepRawLogcat` is explicitly supplied. Credential values are never written
to the manifest.

Account deletion is rejected from every normal/custom suite. It requires the
dedicated suite, a non-QA build, real disposable-account credentials, and the
exact confirmation phrase:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_maestro_android_evidence.ps1 `
  -Suite destructive -BuildProfile debug `
  -DestructiveConfirmation 'DELETE DISPOSABLE ACCOUNT'
```

That command permanently deletes the selected account. Do not use a personal,
shared, historical, or otherwise non-disposable account.

## Recommended execution order

The numbering is the order. It runs cheapest-and-most-depended-upon first, so
a break in authentication fails in seconds rather than after ten minutes of
downstream flows failing for the same reason.

| # | Flow | Priority | Why it sits here |
|---|------|----------|------------------|
| 01 | login | **P0** | Everything else is behind it |
| 02 | signup | **P0** | Fresh-install path; broken signup means no new users |
| 03 | onboarding-tutorial | **P0** | Content-versioned, so it replays for existing users too |
| 04 | smart-planner | P1 | Core value proposition |
| 05 | creator | P1 | The only way data enters the app |
| 06 | si-console | P2 | Advanced surface |
| 07 | timeline | P1 | Reachable from no other navigation surface |
| 08 | progression | P2 | Reachable from no other navigation surface |
| 09 | settings | P2 | Gateway to both destructive actions |
| 10 | subscription | **P0** | Revenue; Play Billing regressions are silent |
| 11 | logout | P1 | Verifies session teardown revokes access |
| 12 | account-deletion | **P0** | Play data-deletion policy; destructive, so last |

Gate 01–03, 10 and 12 as required on `main`. Run the rest nightly.

## Two things to know before editing

**Selector casing.** `HoloButton` uppercases its visible text but exposes the
original casing through `Semantics`. Target `"Timeline"`, not `"TIMELINE"`, for
anything built from `HoloButton`. Screen headers are plain `Text` and really
are uppercase.

**Text selectors are fragile.** Only two widgets in the app carry keys
(`login-email-field`, `login-password-field`). Everything else matches on
visible text, so a copy change breaks flows. If several fail at once after a
wording change, that is the cause. Adding widget keys to the surfaces these
flows touch would make them durable.

## Validation without a device

`dart run tool/validate_maestro_flows.dart` parses every file and checks that
each flow declares an `appId`, has a command list, and that every `runFlow`
target resolves. It runs in CI on every push and catches the errors that
actually happen when editing these files. It is not a substitute for executing
them — only a device can tell you a selector no longer matches.
