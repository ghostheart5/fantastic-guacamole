# Firebase Messaging and Analytics Fix Report

## Scope

This remediation is limited to Firebase Messaging, Analytics, Crashlytics,
Remote Config, related attribution, and tests. Supabase remains the sole
authentication authority.

## Status

| Area | Status | Result |
| --- | --- | --- |
| FCM cold-start notification opens | FIXED | `getInitialMessage()` is mapped through the existing allowlisted notification payload route. |
| FCM resumed notification opens | FIXED | `onMessageOpenedApp` is routed through the same path. |
| Notification-open duplicate delivery | FIXED | Message ID, or the sanitized destination payload fallback, is handled once. |
| FCM refresh persistence and Supabase sync | FIXED | Refreshes use the existing secure cache and authenticated Supabase metadata bridge. Failures are non-fatal and reported. |
| Firebase Analytics Supabase attribution | FIXED | Supabase user IDs are set on session changes and cleared on sign-out. No Firebase Auth is introduced. |
| Crashlytics Supabase attribution | FIXED | The same session lifecycle sets or clears the Crashlytics user identifier. |
| Analytics screen views | FIXED | Route changes are observed through `GoRouter.routerDelegate`. |
| Sign-in and sign-up telemetry | FIXED | Successful email and Google flows emit standard `login`/`sign_up` events. |
| Firebase collection diagnostics | FIXED | Bootstrap records collection state and emits an error when a production release has collection disabled. It never force-enables collection. |
| Remote Config fetch failure | FIXED | Fetch exceptions retain defaults or prior values and record degraded mode. |
| Unused Firebase Auth dependency | FIXED | `firebase_auth` was removed after confirming no application imports. Supabase remains primary auth. |
| Device-level FCM delivery validation | NEEDS_HUMAN_DECISION | Requires a configured Firebase project/device and a real notification send; not appropriate for automated unit tests without credentials. |
| Crashlytics SDK call verification | PARTIALLY_FIXED | Lifecycle code is present and guarded. The unit seam covers Analytics; full Crashlytics SDK verification requires a Firebase-enabled device run. |

## Test Coverage Added

`test/system/firebase/firebase_remediation_test.dart` covers:

- allowed FCM notification destinations and duplicate suppression;
- FCM refresh callback delivery;
- Analytics user attribution, clear-on-sign-out, and screen normalization;
- Remote Config failure fallback to initial defaults.

## Validation

- `flutter pub get`: passed after removing `firebase_auth`.
- `flutter analyze`: passed with no issues.
- `test/system/firebase/firebase_remediation_test.dart`: passed, 4 tests.
- `flutter test`: failed in existing unrelated tests: app boot widget pumping,
  Smart Planner null assertion, timeline filtering widget expectation, SI console
  widget expectation, and trajectory-engine golden comparison. The Firebase
  remediation test passed within that run before the unrelated failures.

## Release Decision

Production readiness is **not granted by this report**. A release owner must
verify Android/iOS Firebase configuration, privacy/consent policy, real FCM
cold/warm notification opens, Analytics DebugView, and a non-fatal Crashlytics
event in the intended production-like environment.