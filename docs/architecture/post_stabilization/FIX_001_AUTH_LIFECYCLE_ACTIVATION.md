# FIX-001 Auth Lifecycle Activation

## Scope

FIX-001 activates the already committed `AuthSessionLifecycleCoordinator` from
`StartupBootstrapGate` in `lib/app/startup/app_bootstrap.dart`. It adds one
app-lifetime activation owner and no second coordinator, boundary, router, or
bridge implementation.

## Startup Contract

After Supabase and auth providers are refreshed, startup passes the current
auth user to the existing lifecycle coordinator's `initialize` operation. The
activation subscribes once to `authStateChanges()` and forwards later changes
to the existing coordinator's `synchronize` operation. Its subscription is
cancelled during the bootstrap gate's disposal.

Same-user refresh handling remains inside the existing coordinator; bootstrap
contains no duplicate same-user branching or account-transition logic.

## Existing Effects Reached by Activation

The coordinator remains the owner of serialized account transitions,
`AuthSessionBoundary` maintenance, session-recovery scoping, mutation draining,
and bridge session-write sequencing. FIX-001 makes that established path
reachable at application lifetime; it does not alter those APIs or semantics.

## Safety Evidence

The focused activation, coordinator, bridge/session-recovery, dispatcher, and
Profile/Learning/ExtendedDomain migration regression suite passes. It verifies
subscription uniqueness, signed-out and authenticated startup, A-to-B and
same-user transitions, disposal, scoped recovery, blocked failure handling,
and migration destination preservation, retry safety, and post-copy cleanup.

The exact index contains only:

- `lib/app/startup/app_bootstrap.dart`
- `test/app/startup/auth_session_lifecycle_activation_test.dart`
- this record

The validation `.env` is sandbox-only, untracked, and excluded from the
commit.

## Deliberate Non-Changes

FIX-001 does not solve router/data-readiness gating, account-scoped core local
persistence, active Profile/Learning/Settings/ExtendedDomain scope, sign-out
retention, reminder account scope, or AI/SI context invalidation. Those remain
for subsequent repairs, including FIX-002's authenticated router/user-data
readiness work.
