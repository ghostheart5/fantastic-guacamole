# Human Root personas

Version: `1.0.0`
All persona executions: `NOT RUN`

Personas are controlled test identities, not real people. Use only assigned
non-production accounts and the matching run-scoped dataset definition.

| ID | Persona | Intent | Required cases |
|---|---|---|---|
| P-NEW | New user | First install, onboarding and first Creator content. | HR-CORE-001, HR-ROOT-002, HR-AUTH-010 |
| P-FREE | Returning free user | Existing account with normal saved activity. | HR-ROOT-001 through HR-ROOT-009 |
| P-PREMIUM | Premium user | Sandbox entitlement, restore and account isolation. | HR-MON-011, HR-AUTH-010 |
| P-HEAVY | Heavy-history user | Large but bounded history and derived root behavior. | HR-ROOT-003 through HR-ROOT-005 |
| P-OFFLINE | Offline-first user | Offline/slow-network use and recovery. | HR-INT-013, HR-ROOT-001 through HR-ROOT-003 |
| P-A11Y | Accessibility user | Screen reader, text scale, contrast, reduced motion and keyboard/switch use. | HR-A11Y-014, HR-ROOT-001 through HR-ROOT-009 |
| P-MIGRATE | Migrating user | Approved prior-version/data compatibility fixture. | HR-REC-012, HR-CORE-001 |
| P-RECOVERY | Corrupted-state recovery user | Explicit, safely created recovery fixture only. | HR-REC-012, HR-INT-013 |
| P-ADVERSE | Adversarial user | Boundary, cross-user, privacy and unauthorized-chat observations. | HR-ADV-015, HR-DEL-016 |
| P-EXPIRED | Expired-session user | Expired/invalid session and reauthentication recovery. | HR-AUTH-010, HR-INT-013 |

Smart Planner and SI Console may be observed in P-FREE/P-ADVERSE but remain
isolated product surfaces. A persona must not create an unauthorized chat
connection, shared draft/state, or direct action path.
