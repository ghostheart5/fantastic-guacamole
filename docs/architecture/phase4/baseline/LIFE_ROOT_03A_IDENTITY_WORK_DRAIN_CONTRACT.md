# LIFE-ROOT-03A — Root-definition correction

## Result

The requested identity-work-drain audit cannot be performed under
`LIFE-ROOT-03`: the authoritative BASE-03 closure assigns identity-work drains
to **LIFE-ROOT-05**, not Root 03. Root 03 contains six legacy-migration and
per-user profile-key diagnostics:

| Contract ID | Closure diagnostic | Lifecycle call |
| --- | --- | --- |
| LEGACY-DEP-01 | LIFE-DEP-03 | `ExtendedDomainService.migrateLegacyStorage` |
| LEGACY-DEP-02 | LIFE-DEP-04 | `ProfileController.migrateLegacyStorage` |
| LEGACY-DEP-03 | LIFE-DEP-05 | `LearningController.migrateLegacyStorage` |
| LEGACY-DEP-04 | LIFE-DEP-06 | `ProfileController.secureStorageKeyForUser` |
| LEGACY-DEP-05 | LIFE-DEP-07 | `ProfileController.secureStorageKeyForUser` |
| LEGACY-DEP-06 | LIFE-DEP-08 | `ProfileController.secureStorageKeyForUser` |

The authoritative lifecycle source awaits the three migrations at lines
489–503 before trusted legacy data may be used in a new authenticated scope.
It uses the profile key helper to capture, apply, and delete signed-out
handoff state. These are storage migration/handoff operations, not queued
identity-work drains.

## Actual identity-work drain contract

`_cancelAndDrainIdentityOwnedWork` at lifecycle lines 1376–1399 is the
identity-work drain owner/coordinator. It awaits repository, sync, recovery,
extended-domain, profile, learning, bridge, reminder, and auth hydration drain
methods together. Those missing APIs are LIFE-DEP-11–16 and 18–21, all assigned
to **LIFE-ROOT-05**. Root 05 also directly overlaps protected HLM-06 settings
work; it must be isolated independently.

## Root 03 dependency state

| Path | Status | HEAD→current hunks | Provenance | Disposition |
| --- | --- | ---: | --- | --- |
| `lib/state/services/extended_domain_service.dart` | dirty | 21 | snapshot-verified per BASE-03 | Root 03 candidate source |
| `lib/state/controllers/profile_controller.dart` | staged/dirty | 17 current diff groups | changed since Phase 2; HLM-06 protected overlap | prerequisite isolation required |
| `lib/state/controllers/learning_controller.dart` | dirty | 4 | snapshot-verified per BASE-03 | Root 03 candidate source |
| `lib/state/providers/auth_session_lifecycle_provider.dart` | untracked | n/a | snapshot-verified | required caller, never a Root 03 commit candidate |

The corresponding HEAD APIs do not provide the migration helpers or per-user
profile key. Current dirty sources provide them, but they are mixed with
user-scoping, queue, state, and unrelated changes. No unknown hunk is selected.

## Consequence

LIFE-ROOT-03 is **BLOCKED** pending a dedicated legacy-migration/profile-key
isolation that accounts for the changed-since-snapshot ProfileController and
the HLM-06 staged boundary. The next identity drain repair, when authorized,
is LIFE-ROOT-05—not Root 03.

## Eventual test matrix

Root 03: absent legacy state, copy-once migration, scoped-key selection,
signed-out handoff, user-A/user-B separation, migration failure containment,
and no overwrite of existing scoped data.

Root 05: no pending work, wait for accepted work, transition gate refusal,
A→B mutation safety, failure recovery, repeated drain, resume after failed
transition, ordering, disposal, and one queue authority.
