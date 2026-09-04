# ChronoSpark Incident Response Runbook

## Scope and evidence boundary

This runbook covers triage and source-level containment for ChronoSpark. A
passing source check does not prove that a deployed Supabase function,
Firebase project, Google Play track, public site, or physical device is healthy.
Record those as separate evidence levels:

1. **Source** — exact branch, commit, configuration, and focused test result.
2. **Artifact** — exact signed or QA artifact identity and inspection result.
3. **Runtime** — emulator or named physical-device reproduction with timestamp.
4. **Service** — authenticated readback from the named deployed environment.
5. **Public/store** — independent public URL or store-console readback.

Never promote a lower evidence level into a higher one. Never paste secrets,
tokens, prompts, task text, email addresses, deletion capabilities, device
identifiers, or user-authored content into an incident ticket or diagnostic
code.

## Severity

- **SEV-0:** credible cross-account disclosure, destructive data loss, active
  credential exposure, or a safety route that encourages harmful action.
- **SEV-1:** authentication bypass, deletion failure, billing authority error,
  repeatable crash on a release path, or notifications exposed after sign-out.
- **SEV-2:** recoverable feature outage, corrupt local state with a preserved
  recovery path, accessibility blocker, or materially misleading public claim.
- **SEV-3:** cosmetic, low-impact, or development-only defect with no data,
  safety, access, or billing consequence.

When severity is uncertain, use the higher level until evidence narrows it.

## First response

1. Record the time, reporter, app version/build, platform, account boundary
   involved, and the lowest evidence level actually observed.
2. Preserve the exact checkout and dirty state. Do not reset, clean, or apply a
   stash as an incident shortcut.
3. Revoke or rotate a credential only through the owning provider console and
   only with explicit authority. Never place replacement values in Git or chat.
4. Contain the affected capability with an existing release gate when possible.
   Do not claim containment until the configured environment is read back.
5. Reproduce with the smallest safe case. Do not use another person's account
   or production data to improve a reproduction.
6. Repair the narrow cause, run focused checks, then run the normal CI gate once.
7. Validate the repaired evidence level and separately list every unverified
   deployment, device, store, or public surface.

## Diagnostic codes

Production-reportable codes come only from `AppDiagnosticCode` in
`lib/core/debug/logger.dart`. Their wire names are fixed, non-sensitive labels;
runtime values must never be interpolated into them. Free-form detail remains
local unless a deliberate verbose development build is used. Crash reporting
also requires the current account's in-memory consent gate and the independent
release configuration gate.

For support reports, ask for the code, app version/build, platform, time, and
reproduction steps. Do not ask for passwords, tokens, raw database rows,
complete prompts, or deletion receipts.

## Playbooks

### Authentication or account isolation

- Stop account-owned reads and writes through the account storage fence.
- Capture only the typed code and transition phase, never an account ID.
- Verify sign-out notification cancellation and provider invalidation.
- Test account A to account B to signed-out transitions with distinct data.
- Treat deployed auth, RLS, and Edge Function behavior as unverified until an
  authorized live readback is performed.

### Data corruption or sync loss

- Preserve the original payload in the existing quarantine/recovery mechanism.
- Do not rewrite a queue if quarantine persistence fails.
- Verify account namespace, mutation drain, idempotency, revision comparison,
  backup validation, and restore behavior independently.
- Never describe a local backup test as proof of cloud durability.

### Account deletion

- Preserve only the opaque pending-deletion capability in secure storage.
- Do not log, display, or transmit that capability outside the status request.
- Confirm requested, pending, completed, stopped-tracking, and local-cleanup
  states separately.
- A source contract does not prove that the deployed deletion worker completed.

### Billing or entitlements

- Fail closed when store authority or server verification is unavailable.
- Never grant access from cached client state alone after an account change.
- Do not claim subscriptions, credit purchases, or a public Play listing while
  those release gates remain disabled or unverified.
- Reconciliation, RTDN, catalog, and refund checks require authorized live
  Google Play and backend evidence.

### Planner, SI, or safety output

- Keep deterministic/on-device output distinct from an external provider.
- External AI is disabled for the current release candidate unless every
  independent provider, retention, safety-review, billing, and release gate is
  approved and read back.
- Preserve the user's ability to reject, correct, or retry guidance.
- Route crisis and non-crisis distress through the dedicated safety policy; do
  not diagnose a user or present planning guidance as professional advice.

### Startup, crash, or recovery

- Use the typed startup/error code and exact build identity.
- Confirm whether the failure is before storage, auth boundary, router, or
  feature initialization.
- Recovery may restore only the supported account-scoped primary view. It must
  not resurrect obsolete task drafts or bypass route authority.
- Test recovery in a focused harness before any broad suite or device run.

## Closure

Close an incident only when the original evidence level is repaired and
rechecked. The closure note must include the exact commit or artifact, focused
tests, one CI result when required, and an explicit list of live-service,
physical-device, store, legal, localization, or public checks still pending.
