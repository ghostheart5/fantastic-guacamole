# ChronoSpark External Gates

## Current evidence notice - 2026-09-04

This is an exit-gate register, not a claim that no external work has run. A gate
stays `BLOCKED_EXTERNAL` until all its required evidence is captured with
authorization; a partial configuration/source pass does not close its runtime
or human requirements. Current readbacks are recorded in the
[Phase 7 checkpoint](docs/engineering/SAFE_QUICK_PHASE_7_STATUS_20260904.md),
and the verified signed candidate and focused physical journeys are recorded in
the [Phase 5/6 checkpoint](docs/engineering/SAFE_QUICK_PHASE_5_6_STATUS_20260904.md).

- Frozen source `61c7331dda9e82201a0561dbcd79aa0b37118446` passed exact-source
  CI (2,352 Flutter tests, 15 configuration tests and static/golden/integration/
  coverage gates). Its signed AAB, physical smoke and one task lifecycle passed;
  complete UAT, Play signing authority and final-release approval remain open.
- Live migration inventory and deployed function source matched that candidate;
  RLS/grants and private 5 MiB JSON Storage restrictions were inspected. These
  are not full schema-checksum, adversarial live-journey or restore proof.
- The duplicate subscription-expiry cron job was paused and independently read
  back; durable migration replay and its next scheduled execution remain gates.
- Backup listings, deletion-reconciliation success with empty queues, Auth
  configuration, Firebase project/app identity and saved fatal/non-fatal/ANR
  email preferences have readback. Restore, end-to-end deletion, push and
  incident delivery remain unproved. Analytics/Crashlytics stay disabled.

Domain work is excluded from the current nine-phase closeout scope at the
user's request, not silently completed. Historical stop notes below describe
earlier checkpoints and cannot override newer evidence.

| Gate | Owner | Exact action/location | Required evidence | Expected result | Risk if skipped | Status |
|---|---|---|---|---|---|---|
| Production deployment parity | Product owner + backend engineer | Supabase project dashboard, migrations, Functions, Storage | Exported deployed versions compared with final SHA | Exact parity | Source may not match production | BLOCKED_EXTERNAL |
| Unexpected RLS policies | Backend engineer | Supabase Table Editor and policy catalog | Fresh policy/grant export | Only reviewed least-privilege rules | Cross-account exposure | BLOCKED_EXTERNAL |
| Supabase advisors | Backend engineer | Security and Performance Advisor | Dated clean or dispositioned report | No unresolved critical finding | Security/performance regression | BLOCKED_EXTERNAL |
| Storage restrictions | Backend engineer | Storage bucket policies and lifecycle | Policy export plus adversarial upload tests | Exact paths, MIME, size, quota, lifecycle | Abuse, cost, failed deletion | BLOCKED_EXTERNAL |
| App Check | Mobile/backend owner | Applicable Firebase products and mobile SDK; separately review Supabase endpoint protections | Consumer inventory, valid signed-client tokens, staged rejection tests, and approved enforcement where applicable | Required products reject untrusted clients without breaking approved apps; Firebase App Check is not automatically Supabase protection | API abuse or broken clients | BLOCKED_EXTERNAL |
| Firebase API restrictions | Firebase owner | Google Cloud API Credentials | Dated restriction export | Keys limited to required apps/APIs | Credential abuse | BLOCKED_EXTERNAL |
| Auth redirect allowlist | Auth owner | Supabase Auth URL configuration | Allowlist export and redirect tests | Only intended origins/routes | OAuth takeover or broken auth | BLOCKED_EXTERNAL |
| CAPTCHA/MFA/AAL/rate limits | Auth owner | Supabase Auth security settings | Config export and scenario tests | Meets deletion and abuse model | Account abuse | BLOCKED_EXTERNAL |
| Leaked-password protection | Auth owner | Supabase Auth password settings | Enabled-state evidence | Compromised passwords rejected | Account takeover | BLOCKED_EXTERNAL |
| Email verification | Auth owner | Supabase Auth email settings | Config and new-account test | Verified behavior matches UI | Access/recovery confusion | BLOCKED_EXTERNAL |
| Database backups/PITR | Operations owner | Supabase database backups | Current schedule and retention evidence | Recovery objective met | Irrecoverable data loss | BLOCKED_EXTERNAL |
| Restore drill | Operations owner | Disposable restored project | Timed drill report and integrity checks | Verified recovery | Backups may be unusable | BLOCKED_EXTERNAL |
| Monitoring/alerting | Operations owner | GitHub, Supabase, Firebase monitoring | Alert routes and test notification | Failures reach an owner | Silent outages | BLOCKED_EXTERNAL |
| Reconciliation health | Billing/backend owner | Scheduled reconciliation workflow | Recent successful runs and pending-count evidence | No unmonitored deferred work | Entitlement/deletion drift | BLOCKED_EXTERNAL |
| Telemetry retention | Privacy owner | Firebase Analytics/Crashlytics retention | Exported retention and consent behavior | Matches policy and minimization | Privacy breach | BLOCKED_EXTERNAL |
| Anthropic DPA/retention | Legal/privacy owner | Provider contract and console | Signed DPA and actual retention/ZDR evidence | Matches disclosure | Undisclosed data retention | BLOCKED_EXTERNAL |
| Planner explanation deployment and scrub | Backend + privacy owner | Fresh Supabase project and authorized production project | Migration replay, database lint, deployed function/config readback, one quoted cancellation, one explicitly authorized real-provider test, one refunded failure, and observed content scrub | No model call before all gates; zero charge on cancel/failure; raw replay content removed within the disclosed target; local fixtures are not live-provider proof | Data retention, double charge, or source/deployment drift | BLOCKED_EXTERNAL |
| Privacy/legal review | Qualified reviewer | Final app, policies, data map | Signed dated review | No unresolved launch blocker | Regulatory and trust risk | BLOCKED_EXTERNAL |
| Mental-health-safety review | Qualified reviewer | Final distress/crisis experience and evals | Signed dated review | Safe bounded behavior | Harmful response | BLOCKED_EXTERNAL |
| Billing database replay | Billing/backend owner | Disposable Supabase/PostgreSQL environment | Exact migration replay, database lint, and both billing pgTAP files | Schema, functions, RLS, grants, ordering, lineage, wallets, and cleanup pass from a fresh database | Source SQL may not execute as reviewed | BLOCKED_EXTERNAL |
| Billing recheck worker | Billing/backend owner | Approved token-reacquisition worker plus scheduled queue processing | Claimed/retried/reconciled queue evidence without raw-token persistence | Expired local rows are rechecked against Google Play and cannot be completed by arbitrary service calls | Stale access or unresolvable queue backlog | BLOCKED_EXTERNAL |
| Billing sandbox lifecycle | Billing owner | Play sandbox/test accounts | Purchase, pending, acknowledgement, renewal, lapsed re-subscription, replacement, cancellation, grace, hold, pause, expiry, revoke, refund, restore, detached-account recreation, account-change, and process-death evidence | Authority and allowance grants are correct for every state | Revenue/access failure | BLOCKED_EXTERNAL |
| Real Android/TalkBack | Accessibility tester | Representative hardware | Recorded matrix and defects | Required journeys pass | Exclusion/trap | BLOCKED_EXTERNAL |
| First-time human UAT | Product research owner | No-coaching UAT protocol | Participant results and retest | All mandatory tasks pass | Adoption/trust failure | BLOCKED_EXTERNAL |
| Production credentials/signing | Release owner | Protected release environment | Signed artifact and provenance | Exact final SHA/artifact | Cannot release safely | BLOCKED_EXTERNAL |
| Google Play publication | Release owner | Google Play Console | Explicit later authorization | Controlled rollout only | Unauthorized publication | BLOCKED_EXTERNAL |

## Historical Phase 2 Stop Evidence

- Exact local commit: `55d245a45f7d2ba7d8d587bb9365e4d8c396350f`.
- `docker` command: unavailable in the current PowerShell environment.
- `supabase` command: unavailable in the current PowerShell environment.
- Consequence: fresh migration replay, pgTAP, database lint, and disposable two-device/deployed-backend verification cannot run locally.
- Required next environment: a disposable Supabase project or functioning local Docker/Supabase stack, never the production project for first execution.

## Historical Phase 8 Stop Evidence

- Phase 8 is source-complete only; subscriptions, paid credits, external AI, and credit spending remain disabled.
- The repository migration-policy replay, client tests, Edge tests, and static SQL contracts passed locally.
- No migration, function, secret, Play product, RTDN subscription, purchase, acknowledgement, or wallet operation was performed against a live service.
- A disposable PostgreSQL/Supabase runtime is still required for migration replay, pgTAP, and database lint. The production project must not be the first execution target.
