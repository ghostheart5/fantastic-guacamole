# LIFE-REPAIR-04 — Sync actions provider contract

## Decision

**BLOCKED.** No production candidate was created or staged. The required
current `syncActionsProvider` contract cannot be honestly restored from HEAD as
a small façade: it owns serialized operation/cancellation behavior and its
other current consumers require the full action surface.

## Evidence

| Item | Value |
| --- | --- |
| HEAD at audit | `ffc854fc99d407d4a068cbdbc675591415c8d25b` |
| HEAD blob | `b810ac1ec4b43f8c0eed3191778f5025e12f0d4e` |
| Current SHA-256 | `007df078f45f48abd8448b1f602ba9c93ee0b36542454902e41458aafc24e6a2` |
| Phase 2 SHA-256 | `007df078f45f48abd8448b1f602ba9c93ee0b36542454902e41458aafc24e6a2` |
| Current equals snapshot | yes |
| Git status | dirty (`M`) |
| HEAD-to-current hunks | 14 |

The authoritative side is **PROVIDER STALE IN HEAD**. HEAD has separate
`syncToCloudProvider`, `replayOfflineQueueProvider`, and
`restoreFromCloudProvider`, but no equivalent `syncActionsProvider`.

## Required contract

The lifecycle source reads `Provider<SyncActions>` at lines 1376 and 1491,
calls `cancelAndDrain()`, then invalidates the provider. Its minimum lifecycle
semantic is to stop accepting new sync work and await already accepted work.

The current worktree has further authoritative consumers:

- app integration actions call `syncToCloud`, `syncDelta`, and
  `restoreFromCloud`;
- navigation shell calls `replayAndSync`; and
- the legacy future providers delegate to the same action object.

Therefore a no-op `cancelAndDrain` adapter would create a second, false sync
authority and would not satisfy the required drain guarantee.

## Protected hunk inventory

The 14 dirty hunks add: auth-scoped backup keying, auth-scoped offline-queue
storage, authenticated cloud gateway selection, `SyncActions` serialization
and cancellation, future-provider delegation, and guarded queue/service calls.
The `SYNC-ACTIONS-PROVIDER` hunk is intertwined with `SYNC-STATE`,
`SYNC-SERVICE`, `SYNC-DISPATCH`, and `AUTH-LIFECYCLE` changes; none can be
included without their referenced contracts. The working file is
snapshot-verified and remains untouched.

## Blocking dependencies

The full `SyncActions` implementation requires dirty sources outside this
repair:

- `lib/data/services/sync_service.dart`: cancellable `syncToCloud` and
  `syncDelta` APIs;
- `lib/state/services/offline_sync_queue_service.dart`: user storage scope and
  `shouldContinue`/dedupe-removal APIs;
- `lib/data/services/backup_service.dart`: secure profile-state key support;
- `lib/state/controllers/profile_controller.dart`: per-user secure key (also
  changed since the Phase 2 snapshot); and
- current auth-scoped sync consumers.

These are unresolved closure roots or additional protected dirty contracts.
No untracked source is required by this specific provider implementation, but
the dirty dependency closure is not safe to adopt here.

## Validation outcome

No focused candidate tests or candidate analysis were run because no safe
HEAD-derived candidate exists. The prior lifecycle sandbox’s five
`syncActionsProvider` diagnostics remain unresolved (10, 17, 25, 28, 29).

## Next safe action

Do not implement another lifecycle repair from this DAG until a controlled
sync-subsystem boundary is mapped: provider, sync service, queue, backup, and
profile-key contracts must be independently provenance-audited and separated
from HLM-06 before any production candidate is constructed.
