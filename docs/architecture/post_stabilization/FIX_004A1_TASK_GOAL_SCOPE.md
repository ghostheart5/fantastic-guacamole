# FIX-004A1 — Task / Goal V2 account-scoped persistence

## Authority and storage map

Before this repair, `TaskRepository` enumerated every record key in global
`tasks_box`; `GoalRepository` read and wrote its complete `goals_v2` aggregate
in global `goals_box`. Both repositories are constructed by
`repositories_providers.dart`; mutations flow through `SyncMutationDispatcher`
and Root-05 drains then invalidates both providers.

The active authority is `accountStorageScopeProvider`. A ready account uses the
FIX-003 namespace `v2.<base64url(utf8(rawUserId))>` and a separate Hive box:
`tasks_box.<namespace>` or `goals_box.<namespace>`. A signed-out scope uses its
separate V2 signed-out box. An unsafe scope has no box and receives a
transition-safe repository that can drain but cannot read or write.

Separate boxes are selected over key prefixes because Tasks enumerate their
storage. Prefix filtering after a whole-box enumeration would disclose another
account's IDs, tombstones, metadata, or records. Goal aggregates are likewise
box-local.

## Legacy policy

Task legacy ownership is **AMBIGUOUS**: `TaskEntity` has no user field and the
global box has no per-record ownership manifest. Goal legacy ownership is
**AMBIGUOUS**: `GoalEntity.userId` is optional and the historical aggregate can
contain absent or mixed user IDs. The lifecycle owner marker is session-level,
not evidence for each Task or Goal record.

This phase performs no migration. Global/V1 data is preserved, never hydrated
into an authenticated V2 box, never claimed, overwritten, or deleted. A future
migration requires an authoritative per-record ownership manifest plus
copy/verification/failure handling.

## Selected semantic groups

| Path | Group | Included | Excluded |
| --- | --- | --- | --- |
| `lib/data/storage/hive_boxes.dart` | A1-S1 | V2 account-box naming and encryption classification | Other box families |
| `lib/data/storage/hive_service.dart` | A1-S1a | Apply existing Hive cipher policy to V2 Task/Goal boxes | Cipher creation or warmup behavior |
| `lib/data/services/local_user_data_cleanup_service.dart` | A1-S1b | Clear the departing account's V2 Task/Goal boxes | Other cleanup semantics or account scope families |
| `lib/data/di/repositories_providers.dart` | A1-S2 | Task/Goal recreation on scope changes | Auth listeners, lifecycle changes, other repositories |
| `lib/data/repositories/task_repository.dart` | A1-S3 | No-target transition repository; existing drain usable | Task schema, sync payload, domain semantics |
| `lib/data/repositories/goal_repository.dart` | A1-S4 | No-target transition repository; existing drain usable | Goal schema, sync payload, Timeline APIs |

## Proof obligations

Focused tests cover A/B isolation, same-ID coexistence, deletion isolation,
scope-local enumeration, restart persistence, ambiguous legacy preservation,
unsafe-transition write denial, and injected scoped read/write failure without
global fallback. The existing FIX-003 namespace suite remains the authority for
the 516-identity collision corpus. Remote sync identity is unchanged:
`SyncMutationDispatcher` retains the raw authenticated user ID and is never
given the V2 namespace.

FIX-004A2 is ready only after this commit passes exact-index validation; it is
not part of this change.
