# ChronoSpark External Gates

Every row remains `BLOCKED_EXTERNAL` until the required evidence is captured with authorization.

| Gate | Owner | Exact action/location | Required evidence | Expected result | Risk if skipped | Status |
|---|---|---|---|---|---|---|
| Production deployment parity | Product owner + backend engineer | Supabase project dashboard, migrations, Functions, Storage | Exported deployed versions compared with final SHA | Exact parity | Source may not match production | BLOCKED_EXTERNAL |
| Unexpected RLS policies | Backend engineer | Supabase Table Editor and policy catalog | Fresh policy/grant export | Only reviewed least-privilege rules | Cross-account exposure | BLOCKED_EXTERNAL |
| Supabase advisors | Backend engineer | Security and Performance Advisor | Dated clean or dispositioned report | No unresolved critical finding | Security/performance regression | BLOCKED_EXTERNAL |
| Storage restrictions | Backend engineer | Storage bucket policies and lifecycle | Policy export plus adversarial upload tests | Exact paths, MIME, size, quota, lifecycle | Abuse, cost, failed deletion | BLOCKED_EXTERNAL |
| App Check | Mobile/backend owner | Firebase and Supabase protection settings | Enabled configuration and rejection test | Untrusted clients rejected where required | API abuse | BLOCKED_EXTERNAL |
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
| Planner explanation deployment and scrub | Backend + privacy owner | Fresh Supabase project and authorized production project | Migration replay, database lint, deployed function/config readback, one quoted cancellation, one safe mock-equivalent execution, one refunded failure, and observed content scrub | No model call before all gates; zero charge on cancel/failure; raw replay content removed within the disclosed target | Data retention, double charge, or source/deployment drift | BLOCKED_EXTERNAL |
| Privacy/legal review | Qualified reviewer | Final app, policies, data map | Signed dated review | No unresolved launch blocker | Regulatory and trust risk | BLOCKED_EXTERNAL |
| Mental-health-safety review | Qualified reviewer | Final distress/crisis experience and evals | Signed dated review | Safe bounded behavior | Harmful response | BLOCKED_EXTERNAL |
| Billing sandbox lifecycle | Billing owner | Play sandbox/test accounts | Full lifecycle evidence | Authority correct for all states | Revenue/access failure | BLOCKED_EXTERNAL |
| Real Android/TalkBack | Accessibility tester | Representative hardware | Recorded matrix and defects | Required journeys pass | Exclusion/trap | BLOCKED_EXTERNAL |
| First-time human UAT | Product research owner | No-coaching UAT protocol | Participant results and retest | All mandatory tasks pass | Adoption/trust failure | BLOCKED_EXTERNAL |
| Production credentials/signing | Release owner | Protected release environment | Signed artifact and provenance | Exact final SHA/artifact | Cannot release safely | BLOCKED_EXTERNAL |
| Google Play publication | Release owner | Google Play Console | Explicit later authorization | Controlled rollout only | Unauthorized publication | BLOCKED_EXTERNAL |

## Current Phase 2 Stop Evidence

- Exact local commit: `55d245a45f7d2ba7d8d587bb9365e4d8c396350f`.
- `docker` command: unavailable in the current PowerShell environment.
- `supabase` command: unavailable in the current PowerShell environment.
- Consequence: fresh migration replay, pgTAP, database lint, and disposable two-device/deployed-backend verification cannot run locally.
- Required next environment: a disposable Supabase project or functioning local Docker/Supabase stack, never the production project for first execution.
