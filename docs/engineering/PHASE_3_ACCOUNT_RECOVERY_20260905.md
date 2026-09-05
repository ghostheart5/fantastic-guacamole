# Closeout Phase 3 - Account and data recovery

Status: **IN PROGRESS - local recovery repairs PASS; live disposable-account,
Storage cleanup and isolated restore evidence remains**. Started September 5,
2026 at the owner's explicit direction. The owner reports provider credits added,
declared Phase 2 done and directed that it not be reopened here.

## Scope and preservation

- Checkout: `ChronoSpark-app-only-priority2`; branch
  `fix/app-only-readiness-priority2-20260902`.
- Starting HEAD: `0c2449016a36a0cb3ff3e431cbf799cb291c7aea`, with pre-existing
  dirty source, release documents and untracked evidence preserved.
- Two existing helpers support narrow recovery implementation and independent
  review. No model/reasoning override or additional helpers.
- No Claude setup, full-suite rerun, phone use, production restore, account
  deletion, migration, deployment, billing, commit or push is part of this
  initial local repair slice. Stop before Phase 6 for the replacement phone.

## Ordered Phase 3 gates

| Gate | Evidence needed | Current state |
| --- | --- | --- |
| 3A. Recovery source and focused regressions | Preserve verified recovery event, keep reset UI reachable with a recovery session, bind update/completion to that session, reject untrusted link authority; focused service/router/widget tests | **PASS for local source and focused tests; live email journey remains 3B** |
| 3B. Real recovery journey | Approved disposable identity and inbox; actual reset request, email/callback, changed password, old-password rejection, expired/replayed-link handling | Not run; source tests are not a substitute |
| 3C. Account isolation and deletion | Two approved disposable identities, two sessions, cross-account denial, deletion/reconciliation and lingering-token denial, preserved control account | Not run; exact identities and destructive scope must be confirmed first |
| 3D. Storage cleanup | Seeded disposable account objects removed by actual deletion; other account objects unchanged; policy checks distinguished from object evidence | Not run; included only in approved disposable-account exercise |
| 3E. Recovery operations | Isolated restore target, timestamped backup, actual database and object restore, integrity checks and measured elapsed time/data age | Not run; never restore over production or invent Storage-object coverage |
| 3F. Recovery commitments | Owner-approved recovery-time/data-loss targets compared with actual drill measurements | Not agreed; do not invent RTO/RPO |

Existing `supabase/tests/account_deletion_recovery.test.sql` checks durable
request schema, grants, policies and tombstones inside a rollback transaction.
It is not proof of a real deletion journey or object/database restoration.
Earlier Phase 1 disposable-backend evidence remains historical; no duplicate
full database gate is being run for the local recovery-routing repair.

## Initial defect

Phase 2 recorded that `AuthService.authStateChanges()` loses the
`passwordRecovery` event, the general deep-link service rejects custom schemes,
authenticated Auth routes redirect onward, and recovery UI is in AuthGate's
signed-out branch. A URL containing `mode=recovery` must not itself grant
password-change authority. The SDK-verified session/event must control recovery,
including cold-start timing and completion, cancellation and account changes.

## Implemented repairs and evidence

- SDK `passwordRecovery` is retained in a session-bound, memory-only capability.
  A query parameter cannot grant reset authority. Cold-start callback capture is
  attached before the SDK consumes the callback; same-session refresh is retained,
  while ordinary sign-in, sign-out, another session or another account clears it.
- Reset email uses the exact registered native callback. The router gives a
  verified pending reset priority over signed-in/onboarding redirects. AuthGate
  keeps the verified user on the reset form and rejects stale completion/cancel.
- Password change uses the captured session token directly, validates the returned
  account and rechecks the recovery lease. It cannot let a delayed response mutate
  a newer SDK session. Cancel rechecks the lease across cleanup waits before logout.
- Full local backups now serialize with account-storage mutations, preventing a
  mixed snapshot during a concurrent restore/write. Malformed, blank or non-object
  stored profiles now abort backup with a constant non-sensitive error and remain
  preserved; they are no longer converted to a valid-looking absent profile that
  could delete profile data during restore.
- Independent source review passed after three races were repaired: delayed
  password response after account switch, delayed cancel after account switch and
  disposed-controller access after an async completion.
- Focused auth service run: 13 checks passed and one cancel fixture exposed the
  required push-token cleanup dependency. The fixture was corrected without
  weakening production fail-closed behavior; only that failed test was rerun and
  passed.
- Focused router/widget run: 18 checks passed and one recovery widget test exposed
  loss of the current user while the nested stream rebuilt. AuthGate now seeds the
  listener from the current user and does not block verified recovery on a waiting
  auth emission; only that failed test was rerun and passed.
- Backup service run: 43 checks passed and one obsolete test expected corrupt
  profile data to be treated as absent. The expectation was corrected to require
  failure and preservation; only that failed test was rerun and passed.
- Static analysis passed with no issues for backup source/tests and the recovery
  service/source group. Recovery UI/router source compiled in its passing focused
  tests; its combined analyzer invocation stalled without diagnostics and was
  stopped rather than retried repeatedly. `git diff --check` passes.

This closes the local repair gate, not the live journey. No real recovery email,
password change, disposable account deletion, Storage-object deletion or isolated
database/object restore was performed. No migration, deployment, phone action,
full suite, commit or push occurred. Phase 3 is not complete until those separately
authorized live/destructive gates and owner-selected RTO/RPO are completed.
