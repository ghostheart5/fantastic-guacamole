# ChronoSpark Privacy and Safety Data Map

This is an initial source-based map. It does not prove live deployment settings.

| Data/signal | Source classification | Consent/freshness requirement | Local use | External use | Persistence | Current launch state |
|---|---|---|---|---|---|---|
| Current energy/capacity | User-reported or Unknown | Explicit check-in; short expiry | Planning and Nexus only when authorized | None while AI disabled | Do not promote to enduring identity | Unknown by default |
| Emotion | User-reported or Unknown | Explicit emotional-signal consent; revocable | Deterministic guidance only when enabled | Safety-routed content is blocked before external AI egress | Current check-in separate from history | Phase 7 source and host tests pass; qualified review remains external |
| Identity/archetype | Co-authored only | Opt-in review and correction | Profile only after evidence/review | None | Removable with provenance | Inferred identity hidden until co-authoring exists |
| Tasks/goals/habits/notes | User-authored | Account ownership and purpose scope | Decision/evidence domains | Supabase only where enabled and promised | Versioned account-scoped storage required | Several domains incomplete |
| Planner memory | User-approved governed memory | Global consent plus exact purpose/surface, expiry, correction, deletion | Recall only when both consent layers permit | None while AI disabled | Existing receipts remain reviewable after revocation | Phase 1 enforcement in progress |
| Decision evidence/receipts | Calculated from authorized snapshot | Inputs must retain source/freshness | Nexus, Timeline, Trajectory, SI | No external AI required | Correctable receipts/outcomes | Foundation preserved |
| Optional Planner explanation input | Visible deterministic plan clauses and visible evidence summaries only; minimized, not sanitized or anonymized | Separate opt-in, exact pre-send categories, provider/model disclosure, and credit quote | Build a digest-bound packet only when every gate passes | Anthropic through the first-party `planner-explanation` function | First-party content limited to a five-minute idempotency window, then scrubbed to billing metadata | Release-disabled; provider retention and qualified safety review are blocked external gates |
| Optional Planner explanation output | External generated explanation with cited clause IDs | Strict schema, provenance, numeric-precision, mutation, diagnosis, and safety validation | Read-only sibling to deterministic Planner V2 | Anthropic response through first-party function | First-party content scrubbed after the five-minute replay window | Release-disabled; deterministic Planner remains available |
| Analytics | Structured allowlisted events | Explicit opt-in | Operational metrics | Firebase | Retention must be disclosed | Native and Dart collection paths off |
| Crash reports | Structured error codes | Explicit opt-in | Reliability | Firebase Crashlytics | No raw UID or arbitrary intimate text | Native and Dart collection paths off |
| Billing token/entitlement | Provider-observed authority | Account binding and durable lineage | Access decisions | Play/Supabase authority | Terminal states and lineage retained | Paywall disabled |
| Account deletion capability | Server-issued request/receipt | Exact-session destructive consent | Pending/completed recovery | Supabase deletion functions | Secure until terminal result | Typed client flow pending |
| Crisis/distress text | User-authored | Immediate safety purpose only | Deterministic immediate-safety or supportive-distress routing | Blocked from optional external AI | No raw input in routing receipts or telemetry | Source and host fixtures pass; qualified mental-health-safety review remains external |

## Non-negotiable boundaries

- Unknown is valid and must not be converted to a personal-looking number.
- Revocation must stop future collection, context construction, persistence, external transmission, notifications, analytics, and logs.
- Guidance cannot mutate person data without preview and explicit confirmation.
- Production values and secret material are never copied into evidence files.
- Anthropic account-level retention or zero-data-retention status has not been verified. The optional external AI surface must remain unavailable until that evidence and a qualified mental-health-safety review are recorded.
