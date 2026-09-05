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
- **Owner-directed sequencing exception, September 5:** defer the remaining
  Phase 2 provider-credit gate and start Phase 3 now. Do not retry provider
  credentials or require funding before local Phase 3 work. This is deferral,
  not a passed provider check or permission for destructive production tests.

## Ordered phase gates

| Phase | Work and required exit evidence | Status |
| --- | --- | --- |
| 1. Source, security and release records | Session-bound deletion recency; durable duplicate-cron repair; focused source and disposable database verification; consistent release/age/auth records without invented owner decisions | **COMPLETE for source/disposable-backend scope on `1f07020e`; production and device proof remain later gates** |
| 2. Firebase and backend hardening | Exact API-key consumer mapping; staged restriction/App Check applicability; approved redirect and secret decisions; approved deployment/migration with independent readback | **CLOSED AT OWNER DIRECTION: owner reports provider credits added and declared Phase 2 done. The earlier installed-secret check and cleanup evidence remain recorded; no credit-funded recheck was run in Phase 3** |
| 3. Account and data recovery | Focused password-recovery event/route/UI repair and real recovery journey; authorized disposable two-account/two-session isolation and deletion/reconciliation; Storage cleanup; isolated timed database and object restore; agreed RTO/RPO | **IN PROGRESS: recovery event/session/route/UI and local backup-corruption/concurrency repairs implemented; focused source validation passes. Live disposable-account and isolated restore gates remain separately controlled** |
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

Current [Phase 2 repair and live-preflight checkpoint](PHASE_2_BACKEND_HARDENING_20260904.md)
records the native FCM default-off repair, App Check applicability correction,
live key fingerprints/shared consumers and the approved production readback:
`account-delete` v9, reconciler v7, all seven source instances exact, 45 migration
records and one active expiry schedule. Other functions and cron rows were
preserved. The approved Firebase key changes now have independent exact 22-API
readback on all three original keys, with application restrictions unchanged.
The four approved missing Play signing fingerprints are now saved on the existing
production Android app. Full-reload readback at 2026-09-05T14:10:48.223Z confirms
the exact ten-entry set: six originals preserved plus four additions. This is
certificate-registration evidence, not native runtime or release readiness.
No destructive account test or phone use occurred; Phase 3 remains
not started while Phase 2 owner/configuration gates are open.
The 2026-09-05 14:16 UTC completion attempt reached an owner/credential-access
handoff: the signed-in provider account lists zero keys, while the production
secret's unchanged metadata cannot prove old-key revocation or replacement
validity. The owner subsequently explicitly accepted the verified Firebase-only
API allowlists as the Phase 2 baseline, retaining extra per-app restrictions as a
compatibility-dependent follow-up. This is accepted residual hardening, not
completed application restrictions; it is no longer a Phase 2 exit blocker.
At 2026-09-05 14:26 UTC, the owner signed in as `domnichols39@gmail.com`.
Organization-level key inventory revealed the active Personal/Organization key
Dom (`apikey_01JxbP8RRmLPrBaaZkR1fRbb`, created September 2), whose masked ending
matches the exposed key. The zero-key Default workspace view did not include it.
Account access is resolved. The owner explicitly approved disabling this exact
candidate; full-reload readback at 2026-09-05T14:28:01.899Z confirms **Disabled**
on the same record and owner. This is reversible disablement, not deletion; no
old-key test or Supabase secret replacement was performed. Replacement setup,
installation provenance and server-held authentication verification remain open.
The owner created service account `chronospark-supabase-prod`
(`svac_01ErTRqsVrWv8YS4qNsPubbA`). Independent reload at
2026-09-05T14:32:49.142Z verified Developer role, only Default workspace with
Workspace User access, zero keys and zero federation rules. A Default-only,
30-day replacement-key form is prepared but not submitted; key creation, direct
secret installation and protected server verification remain uncompleted.
Subsequent readback confirms the owner-created replacement key
`chronospark-supabase-prod-20260905`, linked to that service account, Default
scope, **Active** under the provider status filter, and saved expiry
**October 5, 2026**. The old Dom record remains Disabled. Following the owner's
direct secret entry, Supabase `ANTHROPIC_API_KEY` shows updated at
**September 5, 14:44:19 UTC**, independently reloaded at
**2026-09-05T14:48:00.949Z**. Saved-update metadata is PASS; secret-content
equality and protected server-held authentication are not yet proven. The exact
new key record ID was not retrieved. A temporary admin-only, non-generating
server check and its removal await scoped approval and a verified protected
invocation path; none was deployed or invoked. Rotate before October 5; no
reminder automation was created. Phase 2 remains open only for the provider
credential verification gate, not another secret-entry handoff.

The owner subsequently approved the temporary protected server check and cleanup.
At **2026-09-05T15:02:37.776Z**, the installed secret reached organization
`481a4381-f1cb-43b2-a749-0d2a408395ac`, expected Default workspace
`wrkspc_015MTvox1RzbTyqFSYqZxUqe`, but the fixed token-count operation returned
**HTTP 400 / insufficient_provider_credits**. This was one focused diagnostic
retry after the initial 400, not a paid message-generation request. The function
required an existing admin secret key; unauthenticated invocation returned 403.
Only the temporary function used custom auth with legacy-JWT verification off.
It was deleted and independently confirmed absent, endpoint 404, by 15:03:22 UTC;
the original seven functions retained their preflight IDs, versions, hashes and
auth settings. Non-secret source/result evidence is retained locally. No funds
were added and no further provider requests were run. The remaining owner action
is resolution of the provider credit gate, then approval for a bounded recheck;
Phase 2 is not marked complete and Phase 3 has not started.

Retained follow-up: stage Android production/legacy signer compatibility; separate
browser restrictions from the shared Windows key only through an approved client
migration; verify both Apple native bundle identities before restrictions. Preserve
all existing clients and identities. Final release review must retain this accepted
residual risk and reassess it if services, clients or API scope change.

## Phase 1 checkpoint

### Completed GitHub validation - 2026-09-05 04:38 UTC

The user-approved 19-file repair/status commit was pushed without force to the
existing feature branch:
`1f07020e309c10b1b3942349cd436948811f2759`.
[Supabase Database Gate run 33944999190](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/33944999190),
attempt 1, completed successfully in 2m14s. Its independently read-back `headSha`
and downloaded `exact-commit.json` both match that full commit; run ID/attempt
also match. No PR was opened, and no other workflow ran for this source commit.

- **PASS:** seven Edge entrypoints type-checked; all 83 Edge tests across ten
  files completed with zero failures, errors or skips. The downloaded JUnit
  includes all ten cases in the new `account_deletion_auth_test.ts` file.
- **PASS:** disposable backend startup and complete migration replay. The log
  explicitly shows `20260905041637_consolidate_subscription_expiry_schedule.sql`
  applied successfully.
- **PASS:** eight SQL contract files / 326 assertions; `Result: PASS`. The new
  `subscription_expiry_schedule.test.sql` is explicitly present and passed all
  nine planned assertions. This is real disposable PostgreSQL execution, not a
  static migration-policy check or production-data test.
- **PASS with warnings:** `supabase db lint --local --schema public --fail-on error`
  and the overall job succeeded. Four `warning extra` unused-parameter findings
  were reported for the existing `public.finish_monetization_provider_recheck`
  function: `p_recheck_id`, `p_lease_id`, `p_provider_event_time`, `p_resolution`.
  Independent source triage confirms its body deliberately raises an exception
  requiring authoritative reconciliation; execution is revoked, and billing
  remains contained off. The provider-recheck worker/token mechanism is existing
  Phase 4 work, not a new Phase 1 regression. These warnings must not be described
  as warning-free schema lint or removed by weakening the fail-closed stub.
- **PASS:** independent local readback using `verify_database_evidence.ps1` on
  the downloaded exact-commit manifest and JUnit, plus separate job-log review
  proving SQL execution after that workflow's early Edge-only evidence step.

Evidence retained locally under `artifacts/phase1-closeout/33944999190/`; raw
generated artifacts remain outside the commit. SHA-256 fingerprints:

| Evidence | SHA-256 |
| --- | --- |
| `artifacts/database-evidence/exact-commit.json` | `A775A5C058DB788A34930C30E57FF64FEF6BFE43B82718B02C12B43EF7CFE759` |
| `coverage/edge-function-tests.junit.xml` | `C884E0A2BD4350291F7BC275D1CC1616C3B91D2E07AA43B339EA30D159C77C30` |
| `database-job.redacted.log` | `E0A35BD041C89DD26BF31FC85D25909F41A03475492DD26E84C8B2200C2DA129` |

The full job log has local startup credentials and terminal formatting redacted.
The 203 earlier untracked artifact files were preserved. No full Flutter suite
was rerun; the earlier 14 focused client deletion passes remain host evidence.
No migration/function was deployed, no production setting changed, and no phone
was used. Local Docker remains broken, but GitHub execution clears the Phase 1
database-validation blocker. Do not rerun this passing workflow merely to test
the documentation-only result record; the validated executable source is the
commit explicitly identified above.

Next is Phase 2 backend/Firebase hardening. Its production/configuration changes
retain their separate approval and live-readback gates; completion of Phase 1
does not establish live deletion, full-product capability or release readiness.

### Preserved pre-run checkpoint

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
