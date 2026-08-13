# LIFE-ROOT-05B — identity lifecycle selected-hunk map

## Decision

No production hunk is authorized yet. All fourteen original diagnostics are
still missing from committed HEAD, but three high-risk mixed boundaries must be
isolated before selection: `profile_controller.dart`,
`settings_repository.dart`, and `domain_usecase_providers.dart`. This prevents
Root-05 from absorbing HLM-05, HLM-06, Root-03, or user-owned work.

## Exact manifest

| Owner ID | Path | Role | Status |
| --- | --- | --- | --- |
| ROOT05-REPO-01 | `lib/data/repositories/task_repository.dart` | drain | MODIFY |
| ROOT05-REPO-02 | `lib/data/repositories/goal_repository.dart` | drain | MODIFY |
| ROOT05-REPO-03 | `lib/data/repositories/habit_repository.dart` | drain | MODIFY |
| ROOT05-REPO-04 | `lib/data/repositories/settings_repository.dart` | drain; HLM-06 overlap | MODIFY |
| ROOT05-DISPATCH-01 | `lib/data/sync/sync_mutation_dispatcher.dart` | dispatcher drain | MODIFY |
| ROOT05-RECOVERY-01 | `lib/state/services/session_recovery_service.dart` | recovery drain | MODIFY |
| ROOT05-SYNC-01 | `lib/state/providers/sync_provider.dart` | SyncActions drain | REQUIRED-NO-CHANGE |
| ROOT05-EXT-01 | `lib/state/services/extended_domain_service.dart` | domain drain | MODIFY |
| ROOT05-EXT-02 | `lib/state/providers/domain_usecase_providers.dart` | domain drain/invalidate helpers | MODIFY |
| ROOT05-PROFILE-01 | `lib/state/controllers/profile_controller.dart` | write drain; HLM-06 overlap | MODIFY |
| ROOT05-LEARNING-01 | `lib/state/controllers/learning_controller.dart` | write drain | MODIFY |
| ROOT05-REMINDER-01 | `lib/state/services/reminder_orchestrator_service.dart` | reminder drain | MODIFY |
| ROOT05-IDENTITY-01 | `lib/state/providers/identity_account_provider.dart` | identity sync | MODIFY |
| ROOT05-INSIGHTS-01 | `lib/state/providers/insights_provider.dart` | cache invalidation | MODIFY |
| ROOT05-LIFECYCLE-01 | `lib/state/providers/auth_session_lifecycle_provider.dart` | authoritative caller | VALIDATION-ONLY-UNTRACKED |

## API coverage and order

The lifecycle already preserves the contract order: suspend writes → all drain
owners (repositories, dispatcher, recovery, SyncActions, ExtendedDomain,
Profile, Learning, bridge, reminder, profile hydration) → invalidate provider
state → ownership/migration/claim → `synchronizeAuthenticatedUser` → hydrate
and bootstrap → complete → conditional resume. The missing calls map one-to-one
to the manifest owners; ExtendedDomain and Insights invalidation are distinct
from their drains and must remain non-destructive.

## Provenance and hunk boundary

The thirteen MODIFY files are tracked-dirty. Eleven are snapshot-verified
baseline sources; Profile and Settings are changed-since-snapshot protected
boundaries. Raw HEAD→current groups reviewed: 261 (per-file counts: 5, 3, 2,
3, 7, 7, 19, 21, 136, 43, 11, 3, 1 in manifest order excluding Sync/Lifecycle).
All are excluded pending a deterministic three-way candidate. Selected: 0;
unknown selected: 0; post-snapshot selected: 0.

For future selection, only members directly supplying the lifecycle calls may
be selected: owner-local gate/drain methods; the two ExtendedDomain helpers;
Profile/Learning write drains; identity synchronization; and Insights cache
invalidation. HLM-05 progression, HLM-06 setting/sound/theme work, Root-03
migration/key work, monetization, and unrelated protected hunks are excluded.

## HLM-06 reconstruction plan

Settings and Profile overlap the protected HLM-06 index. Root-05 must create
HEAD-derived per-file blobs containing only selected member hunks, validate
them in a separate index, commit them, then reconstruct the recorded HLM-06
entries with the Root-05 base included. The lifecycle file is an overlay only.

## Tests and readiness

Eventual tests: each owner drains/no-work/repeat/failure path; gate refusal;
A→B isolation; sync same-user retention and cross-user reset; non-destructive
invalidation; drain-before-invalidate ordering; failed/successful transition
resume; disposal; and duplicate-authority absence (18 cases).

**Readiness: NEEDS-CHANGED-FILE-ISOLATION. Next repair: LIFE-ROOT-05C.**
No dependency may be sourced silently from HLM-06 or the untracked lifecycle
provider, and no lifecycle ordering change is authorized.
