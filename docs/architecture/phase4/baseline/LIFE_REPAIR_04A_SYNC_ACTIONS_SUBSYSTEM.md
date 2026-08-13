# LIFE-REPAIR-04A — Sync actions / cancel-and-drain subsystem

## Scope and reconstructability

`SyncActions` is a dirty, snapshot-verified class defined in
`lib/state/providers/sync_provider.dart`. It is an application façade over the
existing `SyncService`, `OfflineSyncQueueService`, and sync state providers,
not an independent durable sync engine. It becomes the canonical action gate:
the current future providers delegate to it, and it owns only in-memory
serialization/in-flight tracking.

The raw HEAD-to-current diff has **17 syntactic blocks**. The prior 14-hunk
count is reproducible only as **14 semantic hunks** by combining the two
adjacent queue-scope blocks and three dispatch-helper blocks. This document
uses the 14 semantic hunk map below.

The subsystem is **PARTIALLY RECONSTRUCTABLE**. It requires a controlled
multi-file sync baseline repair (shape **B**), not a direct provider-only
repair. No production source was changed.

## Semantic hunk map

| ID | Region / symbols | Class | Required role |
| --- | --- | --- | --- |
| SYNC-H01 | intelligence import / `authUserProvider` | SYNC-LIFECYCLE | captures user scope |
| SYNC-H02 | backup user ID | SYNC-STATE | user-scoped backup construction |
| SYNC-H03 | `secureProfileStateKey` | SHARED-BOUNDARY | per-user profile persistence |
| SYNC-H04 | offline queue scope (two raw blocks) | SYNC-STATE | isolates queued work per user |
| SYNC-H05 | sync-service user ID | SYNC-LIFECYCLE | binds cloud path to authenticated user |
| SYNC-H06 | guarded cloud gateway | SYNC-RUN | rejects unauthenticated cloud sync |
| SYNC-H07 | `syncActionsProvider` | SYNC-ACTIONS-PROVIDER | one façade per Riverpod lifetime |
| SYNC-H08 | `SyncActions` fields / serialization | SYNC-ACTIONS-TYPE | cancellation gate and operation tail |
| SYNC-H09 | `syncToCloud` | SYNC-RUN | replay then upload/queue handling |
| SYNC-H10 | `replayOfflineQueue` | SYNC-REPLAY | guarded deterministic replay |
| SYNC-H11 | `syncDelta` | SYNC-RUN | guarded delta sync/queue handling |
| SYNC-H12 | `restoreFromCloud` | SYNC-RESTORE | guarded restore and state invalidation |
| SYNC-H13 | future-provider delegation | SYNC-DISPATCH | removes parallel action paths |
| SYNC-H14 | queued-action helper (three raw blocks) | HELPER | passes continuation guard to sync service |

All 14 are related to the façade. H02–H06 also establish user scope and thus
cannot be safely treated as formatting or incidental additions.

## Exact type and provider contract

`syncActionsProvider` is `Provider<SyncActions>`. It creates one
`SyncActions(Ref)` instance and registers `dispose` through `ref.onDispose`.

`SyncActions` fields are: `Ref`, `_cancelled`, serialized `_operationTail`, and
one in-flight future each for sync, delta, restore, and replay. Its public
methods are `syncToCloud`, `replayOfflineQueue`, `syncDelta`,
`restoreFromCloud`, `replayAndSync`, `cancelAndDrain`, and `dispose`.

## Action and cancellation semantics

All operations serialize through `_operationTail`; duplicate calls of the same
kind share their current future. `cancelAndDrain` sets `_cancelled` and awaits
the operation tail while swallowing prior operation errors. It does not abort a
network request mid-flight; it prevents queued work from starting and supplies
continuation predicates at queue/service checkpoints. It neither clears queue
state nor resets sync state. Disposal sets the same cancellation gate; a new
provider instance is created for a later session.

During auth transition, lifecycle code reads the façade, includes
`cancelAndDrain()` in its all-work drain, then invalidates the provider. This
means active work settles to success/failure/cancelled result before old user
scope is invalidated. Repeated cancellation is idempotent. A failed operation
does not poison a future façade because the serialized tail absorbs errors.

`syncToCloud` replays queued items, uploads if still needed, and queues a
failed upload. `syncDelta` executes guarded delta sync and queues failure.
`replayOfflineQueue` replays guarded queue entries. `restoreFromCloud` performs
guarded restore, clears stale queued mutations, and invalidates restored state.
All use the captured authenticated user plus `canContinue` checks to prevent
old-user writes. Each belongs to the same coherent façade: current runtime
consumers call all four action families.

## Consumers and minimum API

There are three external authoritative runtime consumers: auth lifecycle
(`cancelAndDrain` and invalidation), app integration actions (sync/delta/
restore), and navigation shell (`replayAndSync`). Existing future providers
also delegate to the façade. Three focused/integration tests directly exercise
the sync/delta/restore surface.

The minimum current runtime API is therefore all seven public methods, not only
`cancelAndDrain`. A smaller façade would leave app integration/navigation on a
second action authority or falsely claim to drain existing work.

## Dependency closure and provenance

Required tracked-dirty files are: `sync_provider.dart`, `sync_service.dart`,
`offline_sync_queue_service.dart`, `backup_service.dart`, `profile_controller.dart`,
`domain_usecase_providers.dart`, `goals_provider.dart`,
`optimization_provider.dart`, `task_provider.dart`, `repositories_providers.dart`,
and `intelligence_provider.dart`. There are **11 tracked-dirty** and **0
untracked** required files in this direct manifest.

Nine are snapshot-verified; `profile_controller.dart` and
`domain_usecase_providers.dart` changed since snapshot. The key transitive
contracts are user-scoped queue storage, continuation-aware queue/service/
backup calls, per-user profile storage, auth-user/supabase providers, and
post-restore state invalidation.

No historical committed `SyncActions`, `syncActionsProvider`, or
`cancelAndDrain` implementation was found. The current snapshot is the only
implementation evidence.

## Invariants and test plan

1. One provider resolves one façade and no second action authority exists.
2. Cancellation prevents queued lifecycle-sensitive work from beginning.
3. The operation tail settles before drain returns.
4. Repeated cancel/drain is safe.
5. Sync, delta, restore, and replay retain their current guarded behavior.
6. Auth lifecycle can drain then invalidate the façade.
7. User change prevents old scope writes and queue reuse.
8. Provider disposal gates later work; a new session receives a new façade.
9. Failures do not poison a later-session façade.
10. Restore does not replay stale queued mutations.

## Recommended next shape

**B — MULTI-FILE SYNC BASELINE REPAIR.** Before implementation, each of the
11 manifest files needs a controlled candidate/provenance boundary, especially
the two changed-since-snapshot files and any overlap with HLM-06. Do not commit
the lifecycle provider or HLM-06 with this subsystem.
