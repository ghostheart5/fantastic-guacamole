# LIFE-REPAIR-04B — Multi-file sync baseline boundary

## Decision

The minimum coherent SyncActions subsystem is 11 files. The repair mode is **C — HYBRID**: deterministic HEAD-derived candidates for nine snapshot-verified files and selective candidates for the two changed files. The next action is **NEEDS-CHANGED-FILE-ISOLATION**. No production candidate is authorized yet.

## Manifest

| Path | Role | Status / snapshot | Current SHA-256 | Required role |
| --- | --- | --- | --- | --- |
| `state/providers/sync_provider.dart` | SYNC-FACADE / CORE | dirty, MATCH | `007df078f45f48abd8448b1f602ba9c93ee0b36542454902e41458aafc24e6a2` | façade, gate, dispatch |
| `data/services/sync_service.dart` | SYNC-SERVICE / CORE | dirty, MATCH | `d34a6e6ec2455b7c98ba7521ac30eb4f1065a22f5d1df923d40fcb0e95599be5` | guarded sync/delta/restore |
| `state/services/offline_sync_queue_service.dart` | SYNC-QUEUE / CORE | dirty, MATCH | `20e566d6149e304ae0b0303e1d158ff9667c2b854494da01267c2c3c924dcac7` | scoped ordered queue |
| `data/services/backup_service.dart` | SYNC-RESTORE / CORE | dirty, MATCH | `ef0337d578e62b18dd159af215929840a5c7dbf3c673cf7c1c45ec5d38416eb4` | guarded restore/profile key |
| `state/controllers/profile_controller.dart` | SYNC-STATE / ADAPTER | dirty, CHANGED | `017fa008655b58a1578656cc51cc0243911524f51edbdd0ae5d6c23c336e1132` | profile key/invalidation |
| `state/providers/domain_usecase_providers.dart` | SYNC-DISPATCH / ADAPTER | dirty, CHANGED | `d876d34d735364d70b891c73d8648c49a3e635ff42fdb6fa0037c50399aa3364` | restore queue store |
| `state/providers/goals_provider.dart` | SYNC-STATE / ADAPTER | dirty, MATCH | `d05a80809666b91f5873a6e4603d7fb814da05daad56652587bdd823feb55518` | restore invalidation |
| `state/providers/optimization_provider.dart` | SYNC-STATE / ADAPTER | dirty, MATCH | `bc76fc6a44eda0446039d6905780af4d9e2c79cf30c5d44c68c88f1df668cb53` | restore invalidation |
| `state/providers/task_provider.dart` | SYNC-STATE / ADAPTER | dirty, MATCH | `3ae8387375fae577904f45fb712fcb75834ce2c96b616ac0e43e1fb7d755e65e` | restore invalidation |
| `data/di/repositories_providers.dart` | SYNC-REPOSITORY / ADAPTER | dirty, MATCH | `e680dfebd4eb379278702e5977f20fa72377053b65407a0481f1c482f25491c6` | authenticated cloud client |
| `state/providers/intelligence_provider.dart` | SYNC-LIFECYCLE / ADAPTER | dirty, MATCH | `0c16f67957839456b3ce4aaa62dcaab3d192f72586e46b32f4241b3185d1938b` | authenticated user stream |

All are tracked dirty; no direct untracked or generated dependency was found.

## Changed-file audit

`profile_controller.dart` has nine post-snapshot hunks: progression model imports, legacy-level-floor state, and progression calculation. They are **UNRELATED-CURRENT-WORK** to SyncActions. Its required `secureStorageKeyForUser` and write-drain symbols predate the snapshot. `domain_usecase_providers.dart` has one post-snapshot import-removal hunk, also **UNRELATED-CURRENT-WORK**; its required `syncQueueStoreProvider` predates the snapshot. Required post-snapshot hunks: 0. Unknown post-snapshot hunks: 0. Both files nevertheless require an isolation subphase because required snapshot-era symbols are embedded in protected dirty files.

## Snapshot hunk map and method matrix

The nine matching files have 95 raw HEAD-to-current hunks. Required groups are user-scoped cloud/queue identity, continuation-aware sync/restore/replay, profile-key injection, queue serialization, action façade serialization, and post-restore invalidation. Remaining hunks require candidate-level accounting; snapshot identity alone does not authorize whole-file staging.

| Method | Required files |
| --- | --- |
| `syncToCloud` / `replayAndSync` | façade, sync service, queue, backup, profile key, repository client, auth-user provider |
| `syncDelta` | façade, sync service, queue, backup, profile key, repository client, auth-user provider |
| `restoreFromCloud` | façade, sync service, queue, backup, profile key, queue dispatch, task/profile/goal/optimization state |
| `replayOfflineQueue` | façade, queue, sync service, repository client, auth-user provider |
| `cancelAndDrain` / `dispose` | façade gate; safety depends on all action methods using it |

## Ownership and strategy

The candidate retains one `SyncActions` façade, one user-scoped `OfflineSyncQueueService`, one Riverpod state surface, and one `SyncService`/repository cloud path. No duplicate authority is proposed.

Use deterministic external blobs. Matching files use **A — HEAD + snapshot-required hunks**. Profile and domain files use **B — HEAD + current required hunks** after changed-file isolation. No whole dirty file is eligible for staging.

When ready, validate dependency-ordered commits: scoped queue/service/backup primitives; required state/dispatch adapters; then façade/consumer delegation. Each exact index must be binary-safely exported to a short sandbox, run through `pub get`, focused action tests, and targeted lifecycle analysis without unrelated dirty source.

## Tests

Provider uniqueness; sync/delta/restore/replay; replay ordering; restore queue clearing; cancellation, drain, repeatability, and disposal; failure/new-session behavior; user A/B isolation; navigation/app-integration resolution; lifecycle drain; no duplicate authority; and queue round-trip.
