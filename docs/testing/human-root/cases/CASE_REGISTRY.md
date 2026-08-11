# Human Root case registry

Version: `1.0.0`
Candidate status: `NOT RUN`

Every row below is required evidence planning, not a completed result. A
candidate passport supplies the result, timestamp, tester, device, dataset,
evidence links, and defect references. A required `BLOCKED` or `NOT RUN`
case blocks human-root release approval.

| ID | Case | Persona / dataset | Primary owner | Priority | Initial result |
|---|---|---|---|---|---|
| HR-CORE-001 | Fresh-install canonical core journey | New user / D-NEW | Human QA | P0 | NOT RUN |
| HR-ROOT-001 | Nexus arrival, current-state and recovery | Returning free / D-FREE | Human QA | P1 | NOT RUN |
| HR-ROOT-002 | Creator task, goal, habit/routine and note creation | New user / D-NEW | Creator owner | P0 | NOT RUN |
| HR-ROOT-003 | Timeline lifecycle: complete, not-complete, skip, reschedule | Returning free / D-FREE | Timeline owner | P0 | NOT RUN |
| HR-ROOT-004 | Trajectory scenario, stale and incomplete-evidence presentation | Heavy-history / D-HEAVY | Trajectory owner | P1 | NOT RUN |
| HR-ROOT-005 | Progression update and repeat-action idempotency | Returning free / D-FREE | Progression owner | P0 | NOT RUN |
| HR-ROOT-006 | Smart Planner guidance and isolation from SI Console | Returning free / D-FREE | Smart Planner owner | P1 | NOT RUN |
| HR-ROOT-007 | SI Console explanation and isolation from Smart Planner | Returning free / D-FREE | SI Console owner | P1 | NOT RUN |
| HR-ROOT-008 | Profile, account switch, session and deletion boundaries | Expired-session / D-EXPIRED | Profile owner | P0 | NOT RUN |
| HR-ROOT-009 | Settings, permissions, notification and persistence | Accessibility / D-A11Y | Settings owner | P1 | NOT RUN |
| HR-AUTH-010 | Onboarding, authentication, refresh, expiry, logout/login | Expired-session / D-EXPIRED | Authentication owner | P0 | NOT RUN |
| HR-MON-011 | Sandbox subscription, entitlement and restore isolation | Premium / D-PREMIUM | Monetization owner | P0 | NOT RUN |
| HR-REC-012 | Migration and corrupted-state recovery | Migrating, recovery / D-MIGRATE, D-CORRUPT | Release Engineering | P0 | NOT RUN |
| HR-INT-013 | Lifecycle, network, clock, storage and repeated-tap interruptions | Offline-first / D-OFFLINE | Human QA | P0 | NOT RUN |
| HR-A11Y-014 | Every-root accessibility and large-content validation | Accessibility / D-A11Y | Accessibility owner | P0 | NOT RUN |
| HR-ADV-015 | Adversarial privacy, cross-user and unauthorized-chat checks | Adversarial / D-ADVERSE | Security owner | P0 | NOT RUN |
| HR-DEL-016 | Account deletion boundaries and independent verification | Adversarial / D-ADVERSE | Profile owner | P0 | NOT RUN |

## Completion record required per case

- Passport ID, candidate commit SHA and binary SHA-256.
- Case ID, persona, unique run identifier, dataset seed and device-matrix ID.
- Start/end UTC times, network/fault mode, tester and verifier where required.
- `PASS`, `FAIL`, `BLOCKED`, or approved `NOT APPLICABLE` result;
  never infer `PASS` from an absent defect.
- Evidence links/hashes, redacted device logs and screen recording.
- Defect IDs, veto determination, retest reference and verifier signature.

Detailed procedures are [CORE_JOURNEY.md](CORE_JOURNEY.md),
[TOP_LEVEL_ROOTS.md](TOP_LEVEL_ROOTS.md), and
[INTERRUPTION_AND_RECOVERY.md](INTERRUPTION_AND_RECOVERY.md).
