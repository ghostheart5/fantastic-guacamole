# Smoke Readiness Checklist

Date: 2026-06-30
Scope: Safe incremental hardening only, with mock login preserved and paywall unlockable for testing.

Status legend:
- [x] Verified in current workspace (code and/or diagnostics evidence)
- [ ] Requires live device/emulator runtime validation

## Critical Flows

- [x] Onboarding gate routes correctly to login/home based on completion and auth state.
- [ ] Mock login accepts configured tester credentials and routes to home.
- [x] Authenticated user is redirected away from login route.
- [x] Paywall remains bypassable/unlockable in testing mode.
- [x] Restore purchases path works in testing mode without blocking access.
- [x] Focus complete flow updates score, XP, SI state, and memory.
- [x] Focus skip flow updates SI/learning state and notifications.
- [x] Notification scheduling is skipped when permission is denied.
- [ ] Notification permission state is visible in Settings.

## Observability Gates

- [x] Runtime diagnostics captures startup lifecycle events.
- [x] Runtime diagnostics captures notification permission outcome.
- [x] Analytics event instrumented for mock login success.
- [x] Analytics event instrumented for paywall viewed/unlock/restore.
- [x] Analytics event instrumented for focus completed/skipped.

## Verification Commands

- [x] Run workspace diagnostics (no analyzer errors in edited files).
- [x] Run android diagnose script and inspect latest context output.
- [ ] Confirm no regression in mock login and testing paywall behavior.

## Current Blockers

- Remaining blockers are manual UI interaction checks only:
- Mock login runtime confirmation on-device.
- Notification permission status visibility confirmation in Settings.
- End-to-end tester flow confirmation for mock login plus open paywall behavior.

## Notes

- This checklist intentionally excludes auth/paywall policy tightening in QA builds.
- Mock login and test-mode premium behavior are required and intentionally preserved.
