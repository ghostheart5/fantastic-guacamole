# LIFE-ROOT-05D — remaining identity lifecycle hunk selection

## Remaining manifest (11 MODIFY owners)

All are Phase-2 snapshot-verified baseline sources; each current SHA and HEAD
blob was re-recorded during this audit. `sync_provider.dart` remains
REQUIRED-BUT-NO-CHANGE, and the snapshot-verified untracked lifecycle provider
remains a validation overlay only.

| Owner | Path | HEAD blob | API | Selected |
| --- | --- | --- | --- | --- |
| REPO-01 | `data/repositories/task_repository.dart` | `acb0da73` | `Future<void> cancelAndDrain()` | TASK-H01 |
| REPO-02 | `data/repositories/goal_repository.dart` | `a11a4930` | `Future<void> cancelAndDrain()` | GOAL-H01 |
| REPO-03 | `data/repositories/habit_repository.dart` | `81e3f5fa` | `Future<void> cancelAndDrain()` | HABIT-H01 |
| DISPATCH-01 | `data/sync/sync_mutation_dispatcher.dart` | `7277299d` | `Future<void> cancelAndDrain()` | DISPATCH-H01…H03 |
| RECOVERY-01 | `state/services/session_recovery_service.dart` | `e140ed1f` | `Future<void> cancelAndDrain()` | RECOVERY-H01 |
| EXT-01 | `state/services/extended_domain_service.dart` | `38b6e315` | `Future<void> cancelAndDrain()` | EXT-H01 |
| EXT-02 | `state/providers/domain_usecase_providers.dart` | `af4e8fb2` | `cancelAndDrainExtendedDomainSessionState`, `invalidateExtendedDomainSessionState` | EXT-PROVIDER-H01…H02 |
| LEARNING-01 | `state/controllers/learning_controller.dart` | `e1fd451a` | `Future<void> cancelAndDrainWrites()` | LEARNING-H01 |
| REMINDER-01 | `state/services/reminder_orchestrator_service.dart` | `0733363e` | `Future<void> cancelAndDrain()` | REMINDER-H01 |
| IDENTITY-01 | `state/providers/identity_account_provider.dart` | `cc374b3a` | `ChronoSparkIdentity? synchronizeAuthenticatedUser(User?)` | IDENTITY-H01 |
| INSIGHTS-01 | `state/providers/insights_provider.dart` | `9b3c7f4e` | `void invalidateInsightsSessionState(Ref)` | INSIGHTS-H01 |

## Selection semantics

Repository/dispatcher drains close their local admission gate, wait for work
already accepted, absorb prior failures for repeat safety, and never duplicate
the SyncActions facade. Recovery and reminder drains wait for their own queued
operations; reminder drain does not erase durable/OS scheduling configuration.
Learning/ExtendedDomain selection excludes Root-03 migration and all business
metrics. ExtendedDomain provider helpers separate wait/drain from provider
invalidation; invalidation is cache/session reset, never deletion.

Identity synchronization is in-memory only: null clears identity, same-user
sync retains optional fields, and cross-user sync creates a new identity
without inherited optional account state. Insights invalidation clears only the
derived bundle/signature cache after drain.

## Hunk accounting and coverage

Raw groups reviewed: 220. Selected remaining groups: 14. Excluded remaining
groups: 206. Unknown selected: 0. Profile H01 and Settings H01 remain frozen
and are not reselected. All 14 lifecycle diagnostics are covered by the two
frozen groups plus this owner map. No selected hunk changes the established
order: drain → invalidate → cleanup/ownership → migrate/claim → identity
sync/hydrate.

Selected dependencies are current HEAD, another selected owner, or committed
`sync_provider.dart`; none relies on staged HLM-06 or lifecycle-source commit.
HLM-06 dependency count is zero. HLM-06 remains reconstructable after the two
pre-isolated Profile/Settings candidates are committed.

## Implementation grouping and tests

Use **C — dependency-ordered multi-commit**: (1) repository/dispatcher/recovery
drains, (2) controller/service drains, (3) identity synchronization and
provider invalidation. Each can have focused tests; the final matrix has 18
tests covering each owner, repeated/failure drains, A→B isolation, identity
same/cross-user semantics, non-destructive invalidation, order, resume,
disposal, and no duplicate authority.

**READY-FOR-ROOT05-IMPLEMENTATION.**
