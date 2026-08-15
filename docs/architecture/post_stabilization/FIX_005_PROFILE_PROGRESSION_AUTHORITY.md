# FIX-005 — Profile and progression authority

Status: PASS

ProfileController is the sole account-owned Profile authority. It persists only
to `profile_state_v3.<AccountStorageScope.v2Namespace>`. Its canonical snapshot
contains XP, legacy-level floor/effective level, streak, longest streak, name,
last-active date, and profile readiness. Settings sound and the transient
`leveledUp` event are excluded.

`ProfileRepository` is a callback adapter over current controller state and
`applyCanonicalSnapshot`. `ProgressionRepository` is Profile-backed: get/update
XP, level, and streak use the controller write chain and have no Hive authority.
Scope-sensitive providers watch account scope; retained stale adapters fail
closed rather than targeting a new account.

`profile_entity_v1`, `progression_entity_v1`, and `progression_box` are
preserved but inactive, unclaimed, and never fallback/migration sources.
Instrumentation confirms current Progression APIs make no `progression_box`
calls and mutate canonical V3 state only.

The unused `SiEngineDependencies.profile` field was removed. Profile and
Progression surfaces read the same canonical Profile V3 values and own no
independent persistence.

V3 reads fail closed; retries preserve prior V3 truth and legacy values; the
controller write tail and scope generations preserve current-account ordering.

Certification: 163 focused tests plus 120 final regression tests passed
(283/283); targeted analysis reported zero diagnostics. Legacy migration policy:
preserve, inactive, unclaimed, no fallback, no first-account claim.
