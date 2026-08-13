# BASE-01A bridge session-write subsystem isolation

## Evidence

| Version | Identifier |
| --- | --- |
| HEAD bridge blob | `7ed2594bb794b7fd3aa7ac3b23cdf5f8135d25f6` |
| Current SHA-256 | `5135AA8C743839FE06506B7C2B60D59AADF561ED1B5D1A86254E661784A943D5` |
| Phase 2 snapshot SHA-256 | `5135AA8C743839FE06506B7C2B60D59AADF561ED1B5D1A86254E661784A943D5` |

The current bridge is byte-identical to its protected Phase 2 snapshot. No
historical ref contains the exact `_mutationTail` or `suspendSessionWrites`
implementation; the snapshot is the only implementation evidence.

## Dirty hunk map

| Hunk | Region | Classification | Required symbols/behavior |
| --- | --- | --- | --- |
| BRIDGE-H01 | class fields and `cacheFirebaseMessagingToken` | BASE01-GATE, BASE01-QUEUE, BASE01-TOKEN-WRITE-GUARD | `_mutationTail`, `_sessionWritesSuspended`, queued cache write, suspended skip |
| BRIDGE-H02 | `disassociateFirebaseMessagingToken` | BASE01-QUEUE, BASE01-IDENTITY-STABILITY | queued disassociation, captured `expectedUserId`, identity recheck before metadata clear |
| BRIDGE-H03 | `syncFirebaseMessagingToken` and helpers | BASE01-GATE, BASE01-QUEUE, BASE01-DRAIN, BASE01-TOKEN-WRITE-GUARD, BASE01-IDENTITY-STABILITY, BASE01-REQUIRED-HELPER | queued sync, identity checks, `drainMutations`, suspend/resume APIs, `_serialize` |

There are three atomic diff groups and no unrelated bridge hunk. The identity
checks are required: a queued token sync captures the current user ID, then
checks it before token metadata mutation, preventing an old identity from
writing after a transition. H02 uses the same check before clearing metadata.

## Queue and suspension contract

`_serialize` appends each accepted mutation to `_mutationTail`. It replaces the
tail with a completion that swallows the previous operation's error, so a
failed mutation is reported to its original caller but cannot poison later
work. `drainMutations` returns the tail and therefore waits for accepted work
to settle in FIFO order.

`suspendSessionWrites` sets a process-local gate. While suspended, cache and
sync requests enqueue then complete without mutating storage or Supabase
metadata; they are skipped, not deferred or replayed. `resumeSessionWrites`
only enables later requests. Disassociation remains queued because it is the
cleanup mutation whose completion lifecycle code must drain.

## Minimum coherent symbol set

Required public APIs:

- `static void suspendSessionWrites()`
- `static void resumeSessionWrites()`
- `Future<void> drainMutations()`

Required private symbols and changes:

- `_mutationTail`
- `_sessionWritesSuspended`
- `_serialize<T>` with error-isolating tail continuation
- suspension guards in cache and sync writes
- queued cache, sync, and disassociate operations
- captured/rechecked `expectedUserId` in sync and disassociate operations

No second queue or store is permitted.

## Invariants and focused tests

1. Accepted pre-suspension mutations drain in deterministic order.
2. Suspended cache/sync writes do not mutate state and are not replayed.
3. `drainMutations` waits for accepted work, including failures settling.
4. Resume enables new writes only.
5. User identity changes prevent queued stale metadata mutations.
6. One failed mutation does not block later queued mutation processing.
7. Existing token reads remain unchanged.

Focused tests must cover normal/serialized cache and sync writes, suspend/drain/
resume sequencing, stale identity rejection, failure survival, and unchanged
read behavior. The auth lifecycle call chain should compile against the three
public APIs.

## Candidate strategy and decision

Construct externally from the HEAD blob, recreating BRIDGE-H01, H02, and H03
only. Do not copy the dirty file. The candidate is a **PARTIALLY
RECONSTRUCTABLE** shared boundary: its three hunks are independently
attributable as one coherent BASE-01 subsystem, but no hunk may be omitted
without breaking queue/drain or identity-safety semantics.

Decision: **DIRECT BASE-01 REPAIR.** The later BASE-01 candidate must contain
only this subsystem, focused tests, and BASE-01 documentation. It must not
include HLM-06 or any other protected bridge behavior.
