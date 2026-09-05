# ChronoSpark closeout repair phases

Recorded 2026-09-04 America/Chicago (work crossed 2026-09-05 UTC).
This is the new nine-phase closeout plan, not the binder priorities or earlier
13-phase safe-quick plan. Domain/DNS/TLS work is excluded and remains deferred.

## Execution contract

- User authorized the repair phases in order, with exactly two helper agents
  alongside the primary agent and no model/reasoning-setting change.
- Stop before Phase 6 for the user to change the physical phone. Do not interact
  with or replace the existing phone candidate before that handoff.
- Preserve dirty work, historical artifacts, existing signing identity and the
  frozen signed candidate. Never infer production readiness from local tests.
- Use focused checks during repairs; run the required full gate once after the
  final source freeze, then repair and rerun failures instead of repeatedly
  rerunning a huge suite. A blocked, skipped or unexecuted check is not a pass.
- Production migrations/deployments, credential or client restriction changes,
  destructive account testing, paid resources, commit/push and store submission
  retain their explicit authorization gates. Never expose secret values.

## Ordered phase gates

| Phase | Work and required exit evidence | Status |
| --- | --- | --- |
| 1. Source, security and release records | Session-bound deletion recency; durable duplicate-cron repair; focused source and disposable database verification; consistent release/age/auth records without invented owner decisions | **INCOMPLETE: source repairs locally checked; database execution blocked** |
| 2. Firebase and backend hardening | Exact API-key consumer mapping; staged restriction/App Check applicability; approved redirect and secret decisions; approved deployment/migration with independent readback | Not started in this closeout run |
| 3. Account and data recovery | Authorized disposable two-account/two-session isolation and deletion/reconciliation; Storage cleanup; isolated timed database and object restore; agreed RTO/RPO | Not started |
| 4. Disabled product capabilities | Approved release scope; real provider safety/cost/privacy, Play billing lifecycle/reconciliation, two-device sync/conflict/recovery, consent/telemetry/alerts and kill-switch proof for anything enabled | Not started; containment preserved |
| 5. Final candidate | Freeze exact source; one required full CI gate; required rebuild, signing, bundle/version/size/native-symbol evidence and backend parity | Not started; prior candidate evidence preserved, not transferable to new source |
| 6. Physical-device validation | **Pause for phone replacement first.** Then final-candidate journeys, accessibility, reliability, offline/recovery, performance and smoke on the replacement device | Explicit user handoff before starting |
| 7. Human and qualified reviews | Remaining original Priority 6 human-comprehension criteria and qualified Spanish/safety/legal/visual/claims reviews; functioning public support/deletion service | Not started; robots do not substitute for required humans |
| 8. Google Play app completion | Fresh Console readback; declarations, audience, Data Safety, countries/track, reviewer access, assets, signing and eligibility/prelaunch/closed-test proof | Not started; reconcile old closed-test evidence before restarting anything |
| 9. Final release decision | Exact source/build/backend/device/store evidence, owners, rollback and signoff; explicit separate upload/submission/rollout authorization | Not started; no production-ready claim |

Off features can support only a specifically approved contained-release scope;
they cannot be described as completed full-product capabilities. Legal operator,
jurisdiction, countries/track, retention commitments, and qualified review results
must be supplied or verified, never invented. Public content/support/deletion
work remains in scope even though the domain setup itself is excluded.

## Phase 1 checkpoint

Base checkout: `ChronoSpark-app-only-priority2`, branch
`fix/app-only-readiness-priority2-20260902`, base HEAD
`7274e369f589faafe4e0f276cf7ef7cd2610e4b7`.
This checkpoint packages the Phase 1 source changes and status notes for the
user-approved commit/push and exact-source GitHub database gate. The changes
are **not deployed**. The installed signed candidate remains source
`61c7331dda9e82201a0561dbcd79aa0b37118446`.

### Repairs implemented

1. Account deletion authenticates the exact presented bearer using Supabase Auth
   before consulting signed session claims. Recency comes from that session's
   supported AMR authentication timestamp, not account-wide `last_sign_in_at` or
   refreshed token issuance time. Subject/session identity and non-anonymous
   authenticated role fail closed. Existing status/recovery ordering is retained.
   Independent review also found that the password client discarded the Auth
   response and could fall back to an old mutable `currentSession` token after
   a sessionless reauthentication response. The client now requires the returned
   session/token and matching returned-user/session/current-account identities
   before POST, and sends the returned token. This is a narrow request-binding
   repair, not proof of all concurrent account-switch/cleanup scenarios.
2. Forward migration
   `20260905041637_consolidate_subscription_expiry_schedule.sql` preserves the
   old cron job/history while deactivating only the validated duplicate. It
   requires the known identities, command, schedule, database/user, matching
   server/port, active keeper and no unexpected active exact-command third job.
   It is designed to be idempotent after the earlier production operational
   pause. No expiration function is manually executed by the migration.
3. Nine pgTAP assertions were added in
   `supabase/tests/subscription_expiry_schedule.test.sql` for migration result,
   preserved execution identity/connection target and untouched refund cadence.
4. Seven release documents now distinguish historical from current evidence,
   use the bundled 18+ policy and Supabase Auth, and remove stale directions to
   enable Firebase Auth, ship QA bypasses, pin Billing 6, regenerate signing keys
   or treat hosting as already verified. Existing en/es source and qualified
   Spanish-review requirements remain separate facts.

### Evidence obtained

- PASS: 18 focused Deno checks (18 passed, 0 failed): two-session recency,
  refresh/metadata rejection, rejected or malformed claims, recency boundaries
  and existing deletion state-machine regressions.
- PASS: Deno lint/format on the five affected files and type checks for both
  deletion and reconciliation entrypoints.
- PASS: 14 focused Flutter deletion tests (14 passed, 0 failed), including
  sessionless/changed-identity rejection, exact fresh-token use, pending receipt,
  cleanup and backend-failure/timeout regressions. These are local client
  contract tests, not real account deletion or phone testing.
- PASS: two-file Dart analysis (no issues), formatting (zero changes) and scoped
  whitespace check for the client guard. An initial sandboxed test launch was
  stopped after external SDK/cache access stalled; one elevated focused retry
  passed. No duplicate test process or full-suite rerun was used.
- PASS: migration policy replay **static contract**, 45 migration files checked.
- PASS: seven-file documentation scope/link checks and whitespace checks.
- Independent helper reviews performed on both authentication and cron changes;
  the cron connection-target finding was repaired before handoff.
- These Auth tests inject server responses. They do **not** establish deployed
  signature/revocation behavior or a real deletion journey. Those remain Phase 3.
- No full Flutter suite was rerun, no phone was used, and no production migration,
  function deployment, key change, commit, push or release action occurred.

### Blocking gate and safe continuation

**Database test execution: NOT RUN / BLOCKED.** The installed Docker Desktop
backend was started once, but exited. Its 2026-09-05 04:18 UTC log reports failure
to initialize the Ingest listener at its local `sailor-ingest.sock` because the
file cannot be accessed. Logs also report no installed WSL distributions; this
does not by itself establish the root cause of the listener failure. No database
container or cached image inventory could be obtained. No further restart loop,
factory reset, WSL installation, production test or Docker-file deletion was
performed by this task.

The user subsequently approved an allowlisted Phase 1 commit/push, including
status notes, and the existing GitHub **Supabase Database Gate** on that exact
branch/SHA. Its result is pending in this pre-run checkpoint. The database gate
exercises migrations/pgTAP in a disposable backend; this is not authorization to
deploy the migration or modify production. Do not mark Phase 1 complete from
static checks alone or deploy the new migration before its execution gate passes.

After a successful exact-source database gate, separately obtain deployment
authorization in Phase 2 and run real session/deletion proof in Phase 3. OAuth
self-service deletion is not established by accepting an OAuth AMR claim: its
client currently routes to hosted/support verification, which remains a later
account/user-protection verification item.

## Preserved earlier records

- [Earlier Phase 5/6 candidate and phone evidence](SAFE_QUICK_PHASE_5_6_STATUS_20260904.md)
- [Earlier Phase 7 operational backend and Firebase evidence](SAFE_QUICK_PHASE_7_STATUS_20260904.md)

These older records describe their recorded source and live-readback times.
The new source changes above do not retroactively modify those facts.
