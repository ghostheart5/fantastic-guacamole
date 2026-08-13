# LIFE-REPAIR-04E — Authoritative sync selected-hunk map

## Authoritative manifest

The dependency manifest contains **11 files**. The production modified-file
set contains **5 files**. Six dependencies are required for resolution but
their current HEAD symbols are sufficient; they have no LIFE-04 candidate.

| ID | Path | LIFE-04 action | Candidate |
| --- | --- | --- | --- |
| F01 | `state/providers/sync_provider.dart` | MODIFY-IN-LIFE04 | yes |
| F02 | `data/services/sync_service.dart` | MODIFY-IN-LIFE04 | yes |
| F03 | `state/services/offline_sync_queue_service.dart` | MODIFY-IN-LIFE04 | yes |
| F04 | `data/services/backup_service.dart` | MODIFY-IN-LIFE04 | yes |
| F05 | `state/controllers/profile_controller.dart` | MODIFY-IN-LIFE04 | yes |
| F06 | `state/providers/domain_usecase_providers.dart` | REQUIRED-BUT-NO-CHANGE | no |
| F07 | `state/providers/goals_provider.dart` | REQUIRED-BUT-NO-CHANGE | no |
| F08 | `state/providers/optimization_provider.dart` | REQUIRED-BUT-NO-CHANGE | no |
| F09 | `state/providers/task_provider.dart` | REQUIRED-BUT-NO-CHANGE | no |
| F10 | `data/di/repositories_providers.dart` | REQUIRED-BUT-NO-CHANGE | no |
| F11 | `state/providers/intelligence_provider.dart` | REQUIRED-BUT-NO-CHANGE | no |

The domain provider remains in the dependency manifest because backup resolves
its committed `domainTaskRepositoryProvider`; it has zero selected hunks.

## Selected-hunk ledger

Stable raw IDs are assigned in HEAD-to-protected-source order. The four core
sync files contain only sync-subsystem hunks and all their raw groups are
selected. Profile selects only its two helpers.

| File | Raw groups | Selected | Excluded | Classification |
| --- | ---: | --- | --- | --- |
| `sync_provider.dart` | 17 | `SYNC-PROVIDER-H01…H17` | none | façade, gate, run/delta/restore/replay, state, integration, helper |
| `sync_service.dart` | 17 | `SYNC-SERVICE-H01…H17` | none | scoped cloud path and continuation-aware sync/delta/restore |
| `offline_sync_queue_service.dart` | 16 | `QUEUE-H01…H16` | none | user scope, lock, ordered guarded queue operations |
| `backup_service.dart` | 10 | `BACKUP-H01…H10` | none | scoped profile key and continuation-aware restore |
| `profile_controller.dart` | 37 | `PROFILE-SYNC-H01`, `PROFILE-SYNC-H02` | `PROFILE-EXCLUDED-H01…H35` | two scoped-key helpers only; all other protected/post-snapshot regions excluded |

Totals: **97 raw groups reviewed; 62 selected; 35 excluded; 0 unknown
selected; 0 post-snapshot selected.** All selected core groups are
snapshot-verified. Profile selection is recreated from snapshot semantics on
current HEAD, never by copying the snapshot file.

## Method and invariant coverage

| Method / invariant | Selected hunk groups |
| --- | --- |
| provider lifetime, dispose, cancellation gate, repeat cancellation | `SYNC-PROVIDER-H07…H08` |
| `cancelAndDrain`, accepted-work drain | `SYNC-PROVIDER-H08` plus all action groups |
| `syncToCloud`, `replayAndSync` | `SYNC-PROVIDER-H09`, `H14`; `SYNC-SERVICE-H01…H17`; `QUEUE-H01…H16`; `BACKUP-H01…H10`; profile H01/H02 |
| `syncDelta` | `SYNC-PROVIDER-H11`, `H14`; service/queue/backup selections; profile H01/H02 |
| `replayOfflineQueue` | `SYNC-PROVIDER-H10`, `H14`; queue and service selections |
| `restoreFromCloud`, stale queue clearing | `SYNC-PROVIDER-H12…H13`; service/queue/backup selections; HEAD state-provider dependencies |
| one queue/state/engine authority; scope isolation; failure recovery | all selected core groups, with HEAD-only F06–F11 |

The method and invariant matrices are complete. Each selected hunk depends only
on HEAD, another selected hunk, or an F06–F11 required-but-no-change file; no
untracked, excluded, or post-snapshot source is selected.

## Candidate rules and grouping

Every modified file uses a deterministic external blob:

- F01–F04: current HEAD plus the listed snapshot-proven selected semantics;
- F05: current HEAD plus `PROFILE-SYNC-H01/H02` only.

No whole dirty working file is a construction source. The repair is one atomic
commit: the provider’s gated action semantics cannot be independently validated
without its service, queue, backup, and scoped-key contracts.

## Readiness

The dependency closure is self-contained, domain has zero selected hunks, and
HLM-05 remains preserved by F05’s current-HEAD construction. Status:
**READY-FOR-IMPLEMENTATION**.
