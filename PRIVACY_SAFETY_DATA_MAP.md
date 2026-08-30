# ChronoSpark Privacy and Safety Data Map

This is an initial source-based map. It does not prove live deployment settings.

| Data/signal | Source classification | Consent/freshness requirement | Local use | External use | Persistence | Current launch state |
|---|---|---|---|---|---|---|
| Current energy/capacity | User-reported or Unknown | Explicit check-in; short expiry | Planning and Nexus only when authorized | None while AI disabled | Do not promote to enduring identity | Unknown by default |
| Emotion | User-reported or Unknown | Explicit emotional-signal consent; revocable | Deterministic guidance only when enabled | Must not enter AI/telemetry while disabled | Current check-in separate from history | Enforcement pending |
| Identity/archetype | Co-authored only | Opt-in review and correction | Profile only after evidence/review | None | Removable with provenance | Hidden until sufficient evidence |
| Tasks/goals/habits/notes | User-authored | Account ownership and purpose scope | Decision/evidence domains | Supabase only where enabled and promised | Versioned account-scoped storage required | Several domains incomplete |
| Planner memory | User-approved governed memory | Exact purpose/surface, expiry, correction, deletion | Recall only when consent permits | None while AI disabled | Governed-memory contract | Recall/enforcement pending |
| Decision evidence/receipts | Calculated from authorized snapshot | Inputs must retain source/freshness | Nexus, Timeline, Trajectory, SI | No external AI required | Correctable receipts/outcomes | Foundation preserved |
| AI prompt/context | User-authored plus minimized authorized context | Separate opt-in and pre-send disclosure | Prepare only when AI enabled | Anthropic through first-party proxy | Short idempotency window only | Disabled |
| AI response | External generated content | Schema/safety validation | Optional dialogue only | Provider response | Scrub content after short replay window | Disabled |
| Analytics | Structured allowlisted events | Explicit opt-in | Operational metrics | Firebase | Retention must be disclosed | Must default off |
| Crash reports | Structured error codes | Explicit opt-in | Reliability | Firebase Crashlytics | No raw UID or arbitrary intimate text | Must default off |
| Billing token/entitlement | Provider-observed authority | Account binding and durable lineage | Access decisions | Play/Supabase authority | Terminal states and lineage retained | Paywall disabled |
| Account deletion capability | Server-issued request/receipt | Exact-session destructive consent | Pending/completed recovery | Supabase deletion functions | Secure until terminal result | Typed client flow pending |
| Crisis/distress text | User-authored | Immediate safety purpose only | Deterministic routing | No AI until safety gate | Minimize; no telemetry content | Safety repair pending |

## Non-negotiable boundaries

- Unknown is valid and must not be converted to a personal-looking number.
- Revocation must stop future collection, context construction, persistence, external transmission, notifications, analytics, and logs.
- Guidance cannot mutate person data without preview and explicit confirmation.
- Production values and secret material are never copied into evidence files.
