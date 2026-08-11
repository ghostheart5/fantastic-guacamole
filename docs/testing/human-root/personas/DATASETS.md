# Human Root dataset definitions

Version: `1.0.0`
Dataset execution status: `DEFINED — NO SEED APPLIED BY PHASE 9`

Each run uses a unique identifier: `hr-<candidate-short-sha>-<utc>-<random>`.
Every fixture, account alias and generated name is namespaced by it. Record the
actual seed/version in the candidate passport. Do not document passwords,
tokens, private personal data, service-role keys, or production identifiers.

| Dataset | Persona | Controlled state | Safety boundary |
|---|---|---|---|
| D-NEW | P-NEW | New account, no saved content. | Fresh isolated account only. |
| D-FREE | P-FREE | Bounded tasks, goals, habits/routines, notes and Timeline history. | No production import; creator IDs recorded. |
| D-PREMIUM | P-PREMIUM | Sandbox-only entitlement and a separate free account for isolation. | No real purchase/payment instrument. |
| D-HEAVY | P-HEAVY | Bounded high-volume historical fixture with known summary values. | Size/version documented; no raw private note content in evidence. |
| D-OFFLINE | P-OFFLINE | Confirmed local state plus documented network-fault setup. | Fault controls only on test device/environment. |
| D-A11Y | P-A11Y | Long labels, Unicode/emoji and large-content fixtures. | Sanitized text; no sensitive content. |
| D-MIGRATE | P-MIGRATE | Approved previous-version fixture and migration metadata. | Readable backup; no migration deployment. |
| D-CORRUPT | P-RECOVERY | Narrow, reversible corrupted-state fixture approved by engineering. | Never broad-delete/reset; restore/cleanup verified. |
| D-ADVERSE | P-ADVERSE | User A/User B/anonymous boundary fixture. | Separate accounts and records; no privilege escalation. |
| D-EXPIRED | P-EXPIRED | Expiry/refresh fixture with documented non-production control. | Never edit production auth/session state. |

## Cleanup

Cleanup may affect only records, accounts and artifacts bearing the current
run identifier. Verify cleanup by listing/checking the run-scoped records, then
record its result in the passport. No broad delete, database reset, migration
deployment, or production fallback is permitted.
