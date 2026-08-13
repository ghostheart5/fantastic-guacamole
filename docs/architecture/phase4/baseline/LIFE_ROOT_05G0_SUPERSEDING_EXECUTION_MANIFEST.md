# LIFE-ROOT-05G0 — Superseding Root-05 execution manifest

## Authority and freeze

**Audited HEAD:** `a92704a17d5c36607baf155ffa992da64bdff98e`
(`fix(recovery): scope session recovery storage`).  This is the only baseline
for the selection below.

This document **supersedes for implementation count and selection only** the
count summaries in LIFE-ROOT-05D and LIFE-ROOT-05F, and any enumeration in a
LIFE-ROOT-05G prompt.  It does not erase those records as forensic evidence.
Future Root-05 implementation must use only the `R05-xxx` IDs and `EXEC-x`
groups in this document.

No HLM-06 blob, protected dirty lifecycle source, or production source was
modified to make this manifest.

## Historic raw inventory and normalization

The inventory contains 36 historic ID occurrences and 28 distinct historic
labels.  The following is the raw-label normalization; aliases are never
counted twice.

| Historic label(s) | Canonical result | Status |
| --- | --- | --- |
| `TASK-H01`, `TASK-DRAIN-H01`…`H05` | `TASK-DRAIN-H01`…`H05`; `TASK-H01` is an obsolete coarse alias | REMAINING-ROOT05 |
| `HABIT-H01`, `HABIT-DRAIN-H01`…`H02` | `HABIT-DRAIN-H01`…`H02`; `HABIT-H01` is an obsolete coarse alias | REMAINING-ROOT05 |
| `GOAL-H01`, `GOAL-DRAIN-H01`…`H03` | `GOAL-DRAIN-H01`…`H03`; `GOAL-H01` is an obsolete coarse alias | REMAINING-ROOT05 |
| `DISPATCH-H01`…`H03` | Same labels | REMAINING-ROOT05 |
| `DISPATCH-CALL-H01` | Same label | COMMITTED-PRE-01 |
| `RECOVERY-H01` | One inseparable gate + mutation-tail + `cancelAndDrain` contract | REMAINING-ROOT05 |
| `RECOVERY-CALL-H01` | Same label | COMMITTED-PRE-02 |
| `EXT-H01`, `EXT-PROVIDER-H01`…`H02` | Same labels | REMAINING-ROOT05 |
| `PROFILE-ROOT05-H01`, `SETTINGS-ROOT05-H01` | Same labels | REMAINING-ROOT05 |
| `LEARNING-H01`, `REMINDER-H01`, `IDENTITY-H01`, `INSIGHTS-H01` | Same labels | REMAINING-ROOT05 |

The PRE-01 constructor capture, the committed session-boundary API, and the
PRE-02 scoped-key constructor are prerequisite semantics, not separately named
historic production-hunk IDs.  They are classified as
NOT-A-PRODUCTION-HUNK for this count.  The boundary API has no historic stable
group ID, so the count of named groups in COMMITTED-BOUNDARY is zero.

There are **25 canonical historic semantic groups**: 23 remaining groups,
`DISPATCH-CALL-H01` committed by PRE-01, and `RECOVERY-CALL-H01` committed by
PRE-02.  Three obsolete labels (`TASK-H01`, `HABIT-H01`, `GOAL-H01`) are
aliases, not additional canonical groups.

### Recovery resolution

`RECOVERY-H01` remains one canonical group.  Its gate, mutation tail, and
`cancelAndDrain` API are structurally inseparable: the gate prevents newly
admitted recovery mutations, the tail represents accepted mutations, and the
drain waits for that tail.  PRE-02 deliberately committed only `storageScope`,
scoped key use, and `RECOVERY-CALL-H01`; it did not commit any part of
`RECOVERY-H01`.

## The one true remaining execution list

Candidate rule for every entry: construct an exact, HEAD-derived candidate
containing only this listed semantic group.  Do not stage a dirty file
wholesale.  `VL` means the untracked lifecycle source may be used only to
validate a caller contract; it is neither a source dependency nor an item to
commit.

| R05 ID | Canonical legacy ID | Exact owner path | Owner / purpose | Dependencies | HEAD partial? | Diagnostics |
| --- | --- | --- | --- | --- | --- | --- |
| R05-001 | TASK-DRAIN-H01 | `lib/data/repositories/task_repository.dart` | repository fields, drain and dispose | — | NO | drain/task |
| R05-002 | TASK-DRAIN-H02 | `lib/data/repositories/task_repository.dart` | serialize `saveTask` | R05-001 | NO | drain/task |
| R05-003 | TASK-DRAIN-H03 | `lib/data/repositories/task_repository.dart` | serialize `deleteTask` | R05-001 | NO | drain/task |
| R05-004 | TASK-DRAIN-H04 | `lib/data/repositories/task_repository.dart` | queue admission/gate helper | R05-001 | NO | drain/task |
| R05-005 | TASK-DRAIN-H05 | `lib/data/repositories/task_repository.dart` | failure-safe queue-tail maintenance | R05-004 | NO | drain/task |
| R05-006 | HABIT-DRAIN-H01 | `lib/data/repositories/habit_repository.dart` | repository fields, drain and dispose | — | NO | drain/habit |
| R05-007 | HABIT-DRAIN-H02 | `lib/data/repositories/habit_repository.dart` | serialized save/helper gate | R05-006 | NO | drain/habit |
| R05-008 | GOAL-DRAIN-H01 | `lib/data/repositories/goal_repository.dart` | repository fields, drain and dispose | — | NO | drain/goal |
| R05-009 | GOAL-DRAIN-H02 | `lib/data/repositories/goal_repository.dart` | queue admission/gate helper | R05-008 | NO | drain/goal |
| R05-010 | GOAL-DRAIN-H03 | `lib/data/repositories/goal_repository.dart` | failure-safe write tail | R05-009 | NO | drain/goal |
| R05-011 | DISPATCH-H01 | `lib/data/sync/sync_mutation_dispatcher.dart` | cancellation state and drain/dispose API | DISPATCH-CALL-H01 (COMMITTED-HEAD) | NO | dispatcher drain |
| R05-012 | DISPATCH-H02 | `lib/data/sync/sync_mutation_dispatcher.dart` | serialize accepted queue mutations | R05-011 | NO | dispatcher ordering |
| R05-013 | DISPATCH-H03 | `lib/data/sync/sync_mutation_dispatcher.dart` | current-session gate and failure-safe operation tail | R05-012 | NO | dispatcher A→B isolation |
| R05-014 | RECOVERY-H01 | `lib/state/services/session_recovery_service.dart` | gate, mutation tail, serialized recovery writes, drain/dispose | RECOVERY-CALL-H01 (COMMITTED-HEAD) | NO | recovery drain/scope |
| R05-015 | EXT-H01 | `lib/state/services/extended_domain_service.dart` | service drain/dispose and accepted-write tail | — | NO | extended-domain drain |
| R05-016 | EXT-PROVIDER-H01 | `lib/state/providers/domain_usecase_providers.dart` | provider helper to drain extended-domain session state | R05-015 | NO | extended-domain orchestration |
| R05-017 | EXT-PROVIDER-H02 | `lib/state/providers/domain_usecase_providers.dart` | provider invalidation helper | R05-016 | NO | extended-domain invalidation |
| R05-018 | PROFILE-ROOT05-H01 | `lib/state/controllers/profile_controller.dart` | queue/generation fields and `cancelAndDrainWrites` | VL; HLM-06 reconstruction only | NO | profile scope drain |
| R05-019 | SETTINGS-ROOT05-H01 | `lib/data/repositories/settings_repository.dart` | cancellation gate, write queue, drain/dispose | VL; HLM-06 reconstruction only | NO | settings scope drain |
| R05-020 | LEARNING-H01 | `lib/state/controllers/learning_controller.dart` | write tail and `cancelAndDrainWrites` | VL | NO | learning drain |
| R05-021 | REMINDER-H01 | `lib/state/services/reminder_orchestrator_service.dart` | operation tail, gate and non-destructive drain | — | NO | reminder drain |
| R05-022 | IDENTITY-H01 | `lib/state/providers/identity_account_provider.dart` | authenticated-user identity synchronization | — | NO | identity synchronization |
| R05-023 | INSIGHTS-H01 | `lib/state/providers/insights_provider.dart` | derived insight/signature cache invalidation | — | NO | insights invalidation |

The repositories total exactly ten groups: Task 5 + Habit 2 + Goal 3.  All ten
remain after PRE-01 and PRE-02.  Dispatcher has 3 remaining groups;
`DISPATCH-CALL-H01` is committed and excluded.  Recovery has 1 remaining group;
`RECOVERY-CALL-H01` is committed and excluded.

## Counts and production manifest

| Family | Remaining |
| --- | ---: |
| repository drain (Task/Habit/Goal) | 10 |
| dispatcher | 3 |
| recovery | 1 |
| extended domain/service-provider | 3 |
| Profile | 1 |
| Settings | 1 |
| Learning | 1 |
| Reminder | 1 |
| identity sync | 1 |
| invalidation (Insights) | 1 |
| **Total** | **23** |

The 23 groups own **13 unique production paths**:

1. `lib/data/repositories/task_repository.dart`
2. `lib/data/repositories/habit_repository.dart`
3. `lib/data/repositories/goal_repository.dart`
4. `lib/data/sync/sync_mutation_dispatcher.dart`
5. `lib/state/services/session_recovery_service.dart`
6. `lib/state/services/extended_domain_service.dart`
7. `lib/state/providers/domain_usecase_providers.dart`
8. `lib/state/controllers/profile_controller.dart`
9. `lib/data/repositories/settings_repository.dart`
10. `lib/state/controllers/learning_controller.dart`
11. `lib/state/services/reminder_orchestrator_service.dart`
12. `lib/state/providers/identity_account_provider.dart`
13. `lib/state/providers/insights_provider.dart`

`lib/state/providers/sync_provider.dart` is REQUIRED-BUT-NO-CHANGE validation
wiring and is not in the remaining-path count.

## Dependency and self-containment proof

Every dependency in the R05 table is classified as one of:

- **COMMITTED-HEAD:** `DISPATCH-CALL-H01`, `RECOVERY-CALL-H01`, the PRE-01
  captured dispatcher constructor, PRE-02 scoped recovery constructor, and the
  committed session-boundary API.
- **OTHER-R05-GROUP:** only the explicitly listed R05 dependencies.
- **REQUIRED-BUT-NO-CHANGE:** `lib/state/providers/sync_provider.dart`.
- **VALIDATION-ONLY-UNTRACKED:** the protected
  `auth_session_lifecycle_provider.dart` caller overlay (`VL` entries). It is
  never imported by the narrow R05 candidates and is not staged or committed.

Unknown dependencies: **0**.  Uncommitted external source dependencies: **0**.
The lifecycle overlay is a validation artifact, not a build dependency of any
candidate.

Static review confirms each listed path is self-contained as
`CURRENT HEAD + all R05 groups owned by that path`: constructors and imports
remain HEAD-compatible; repository and service fields are paired with their
helpers; provider helpers reference only their owner service; and the two
committed caller contracts supply the changed constructors.  Profile and
Settings require deterministic reapplication of their recorded HLM-06 blobs
after their HEAD-derived Root-05 commits, but do not require an HLM-06 source
change.  **All groups self-contained: YES.**

## Execution DAG

| EXEC group | R05 IDs | Production paths | Earlier dependencies |
| --- | --- | --- | --- |
| EXEC-1 | R05-001…R05-010 | task, habit, goal repositories | none |
| EXEC-2 | R05-011…R05-014 | dispatcher; recovery service | EXEC-1 not required; committed PRE callers required |
| EXEC-3 | R05-015…R05-017 | extended-domain service and domain-usecase providers | EXEC-2 not required |
| EXEC-4 | R05-018, R05-019 | Profile controller; Settings repository | none; deterministic HLM-06 reconstruction follows |
| EXEC-5 | R05-020, R05-021 | Learning controller; reminder orchestrator | EXEC-4 integration validation |
| EXEC-6 | R05-022, R05-023 | identity-account provider; insights provider | EXEC-1…EXEC-5 integration validation |

Every R05 ID appears in exactly one execution group.

## Finalized 25-test matrix

| Test | Coverage |
| --- | --- |
| T01–T05 | R05-001 through R05-005: Task drain, save order, delete order, closed admission, failed-write repeat safety |
| T06–T07 | R05-006 through R05-007: Habit drain and serialized save/gate |
| T08–T10 | R05-008 through R05-010: Goal drain, gate, failed-tail repeat safety |
| T11–T13 | R05-011 through R05-013: dispatcher drain, operation order, captured A→B scope isolation |
| T14 | R05-014: recovery gate/tail/drain and scoped recovery isolation |
| T15 | R05-015: extended-domain accepted-write drain/dispose |
| T16–T17 | R05-016 and R05-017: provider drain helper and non-destructive invalidation |
| T18 | R05-018: Profile generation/write-tail drain and HLM-06 blob reconstruction check |
| T19 | R05-019: Settings cancelled queue/drain and HLM-06 blob reconstruction check |
| T20 | R05-020: Learning write-tail drain |
| T21 | R05-021: Reminder drain preserves durable/OS configuration |
| T22 | R05-022: same-user retention, cross-user reset, and null clear |
| T23 | R05-023: derived Insights cache/signature invalidation only |
| T24 | Integration: transition order across repositories, dispatcher, and recovery |
| T25 | Integration: A→B isolation across Profile, Settings, Learning, extended domain, Reminder, Identity, and Insights |

Finalized test count: **25**.  Each R05 group has direct coverage in T01–T23
or explicitly documented integration coverage in T24/T25.

## Ready gate

All remaining semantic groups have unique R05 IDs and exact owners; counts
reconcile; PRE groups are excluded; recovery ambiguity is resolved; dependencies
have no unknown or uncommitted external source; all candidates are statically
self-contained; and every R05 ID has one EXEC owner.

**Next action: READY-FOR-ROOT05-EXECUTION.**

**LIFE-ROOT-05 status: SAFE WITH CONDITIONS.**  Conditions: execute only the
HEAD-derived R05 candidates above, preserve the protected lifecycle source,
and deterministically reconstruct the already-staged HLM-06 blobs after
EXEC-4.
