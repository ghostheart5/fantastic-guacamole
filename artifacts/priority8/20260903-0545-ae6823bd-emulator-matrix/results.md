# Priority 8 bounded emulator matrix results

Current verdict: **PASS WITHIN THE LOCAL QA EMULATOR SCOPE**. Profile
startup/memory, the canonical learned-lifecycle journey, and Account A ->
Account B -> Account A preservation/isolation now pass. Production cloud sync,
physical-device behavior, and signed-release behavior remain outside this
evidence scope.

Source commit label: `ae6823bd9f03640834cfc52442d70cbf5d8135b3`

Final repaired QA profile APK SHA-256:
`9770E55645D698A0E09DF1A6E44FEF3C3824C0FFD2B2CCBC401CF666D43A09CC`

Target: `emulator-5558`, Android 16 / API 36, `ChronoSpark_API_36`.

This is emulator-substitute evidence. It does not prove physical-device behavior,
signed-release behavior, production backend behavior, or real-user account
switching.

## PASS

- Portrait widths 320, 360, 390, and 428 logical dp at 200% font scale rendered
  the tested onboarding/login controls without a fatal marker. Evidence:
  `width-320dp-rerun/`, `width-360dp/`, `width-390dp/`, and `width-428dp/`.
- The 320dp password-visibility target was repaired from 18x18dp to 48x48dp.
  Final focused evidence: `width-320dp-touch-target-rerun/window2.xml`.
- Keyboard-open 320dp/200% login remained scroll/recovery reachable without a
  focus trap. Evidence: `keyboard-open-320dp/`.
- Landscape 360dp/200% copy no longer sits underneath a fixed CTA. The CTA is
  scroll-reachable, fully visible, and measured `[1160,196][1520,368]`, or
  180x86 logical dp at density 2. Evidence:
  `landscape-360dp-200pct-final/initial.png`,
  `landscape-360dp-200pct-final/action-fully-visible.png`, and
  `landscape-360dp-200pct-final/window-action-fully-visible.xml`.
- The focused 800x360/200%-text widget regression passed after the landscape
  repair: `landscape 200 percent text keeps the login action after copy`.
- Reduced-motion settings were fixed at animator/transition/window scales
  `0/0/0`; labeled UI remained present and fatal markers were zero. Evidence:
  `reduced-motion/`.
- TalkBack was installed, enabled, and bound as
  `com.google.android.marvin.talkback/.TalkBackService`. Keyboard traversal
  visibly focused the labeled Welcome element and then the complete
  `CONTINUE TO LOGIN` action; activation reached the login UI. The login
  hierarchy exposed Email address, Password, Show password, ENTER SYSTEM, and
  TESTER ACCESS. Evidence: `talkback/tab-focus.png`, `talkback/tab-4.png`,
  `talkback/login-window.xml`, and `talkback/login.png`.
- Offline resilience and reconnect recovery passed. With airplane mode on,
  the route table was empty, ping returned `Network is unreachable`, the app
  drew the login UI at `+15s983ms`, and fatal markers were zero. After airplane
  mode off and Wi-Fi reconnection, ping received one response, labeled login UI
  returned at `+8s768ms`, and fatal markers remained zero. Evidence:
  `offline-reconnect-final/offline.png`,
  `offline-reconnect-final/reconnect.png`, and
  `offline-reconnect-final/reconnect-window.xml`.
- Force-stop/relaunch recovery succeeded 2/2 with distinct PIDs `12088` and
  `12224`; each run produced a fully drawn frame and zero fatal markers.

## Earlier debug-only failures (superseded by profile follow-up)

- Cold-start budget (both runs must be <=12,000ms): FAIL. Formal run 1 reported
  `am start -W` timeout, `WaitTime 12,712ms`, and Android fully drawn
  `+12s878ms`. Run 2 passed at `TotalTime 6,824ms`. Earlier bounded fresh starts
  also produced fully drawn `+15s139ms` and `+22s803ms`, confirming the slow run
  was not an isolated command parsing error.
- Memory budget (both runs must be <=350,000KB total PSS): FAIL. Formal settled
  runs measured `414,706KB` and `405,167KB` total PSS.

## Evidence boundary

- Production cloud synchronization remains unverified because this QA build uses
  isolated local tester identities with cloud services disabled.
- Physical-device and signed-release behavior remain unverified; this matrix is
  an emulator substitute only.
- TalkBack service binding, visible focus traversal, action activation, and
  labeled hierarchy are proven. Audio capture of spoken phrasing/order was not
  available, so spoken-output quality is not claimed.

## Narrow repairs made from failed checks

- `lib/features/auth/ui/login_screen.dart`: password-visibility semantics and
  hit target now fill the 48dp minimum.
- `lib/features/onboarding/ui/onboarding_screen.dart`: landscape CTA now follows
  the welcome copy inside the scroll surface; CTA height grows with 200% text.
- `test/onboarding/onboarding_screen_test.dart`: focused 800x360/200%-text
  containment and reachability regression.
- `.maestro/subflows/skip-onboarding.yaml`: bounded cold-start stabilization.
- `.maestro/flows/03-onboarding-tutorial.yaml`: bounded welcome readiness wait.
- `.maestro/flows/05-creator.yaml`: focused Creator tap stabilization.

No broad Flutter suite or already-passing Maestro flow was rerun by this role.

## Startup-performance follow-up

The earlier debug-mode performance failures were resolved as an evidence-mode
and host-contention issue, not an app-source regression. After stopping only the
released 5554/5556 emulators, a profile QA APK built successfully and passed the
unchanged cold-start and memory budgets twice: `5,796ms / 177,390KB` and
`3,941ms / 192,799KB`, with focused labeled UI, 2/2 recovery, and zero fatal
markers. Exact evidence and boundaries are in `profile-startup/results.md`.

## Canonical learned-lifecycle follow-up

The bounded profile journey proved onboarding -> Creator -> Timeline -> Nexus ->
Smart Planner input/output -> Use this plan -> scheduled Creator confirmation ->
Timeline completion -> Nexus `WHAT LEARNING CHANGED` -> process restart -> QA
reauthentication -> persisted Planning & guidance evidence, with zero fatal
markers. The exact post-restart composite row containing `Task Lifecycle`,
`completed`, `Completed the task.`, and `helped` passed in the focused 38-second
state-preserving readback at
`../../canonical-learned-lifecycle-readback/20260903-072900-ae6823bd-custom/`.

## Account-switch repair and verification

The account-switch blocker was repaired by scoping active account-owned Hive,
SecureStore, and SharedPreferences data, preserving proven-owner legacy data,
failing closed for signed-out or unowned data, and rotating dependent providers
when the authenticated account changes. Local cleanup now deletes only the
departing account namespace and preserves device-global and other-account data.

Focused final-state evidence:

- The account-focused regression portfolio covers 212 tests: 157 unaffected
  cases passed in the consolidated run, then the corrected paywall account-state
  file passed 55/55. Its six stale accountless fixtures were the only failures in
  the consolidated run and all six passed after being aligned to authenticated,
  account-scoped state.
- Navigation/account fixture verification passed 29/29.
- Analyzer passed all 72 changed Dart files with zero issues; formatting and
  `git diff --check` are clean.
- `dart run tool/validate_maestro_flows.dart` passed all 21 discovered flow
  files.
- The exact repaired profile APK built successfully, installed on
  `emulator-5558`, and reported version `4.1.0` / version code `2026083003`.
- Maestro `priority8-account-isolation.yaml` passed the full local journey:
  create Account A sentinel -> switch to Account B -> prove A absent -> create B
  sentinel -> switch back to A -> prove A restored and B absent.
- Completed console evidence is in
  `../account-isolation/20260903-094204-ae6823bd-dirty/maestro-console.txt`.
  The user-requested extra rerun was stopped after confirming the first run had
  already passed; it is not counted as evidence. The post-stop emulator log had
  zero `FATAL EXCEPTION`, `FlutterError`, or `Unhandled Exception` markers.

This verifies local QA account isolation and preservation on the emulator. It
does not claim real Supabase account switching or production cloud-sync proof.
