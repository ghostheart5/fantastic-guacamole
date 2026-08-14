# FIX-004C — Durable SI Memory Runtime Handoff

## FIX-004C1 — Memory V2 account authority

### Defect and authority

The prior active Memory authority was the global `memories_v1` key. That
allowed a `MemoryRepository` instance and its `memoriesProvider` projection to
read authenticated content without an account namespace.

The canonical authenticated authority is now
`memories_v2.<AccountStorageScope.v2Namespace>`. `MemoryRepository` requires
an authenticated, ready `AccountStorageScope`; unsafe, transitioning, and
signed-out scopes fail closed and never fall back to `memories_v1`.

`memories_v1` is a legacy, ownership-ambiguous record. It is preserved,
inactive, unclaimed, unhydrated, and never deleted by this repair.

### Provider handoff

`memoryRepositoryProvider` watches `accountStorageScopeProvider`.
`domainMemoryRepositoryProvider` watches the repository provider, and all
Memory get/save/delete use-case providers watch the domain repository.
`MemoriesNotifier.build` watches `getMemoriesUseCaseProvider`. This makes the
repository, use cases, and `memoriesProvider` projection recreate for a new
account scope rather than retaining A-owned state in B.

### Compatibility correction

The corrupt-snapshot repository test now seeds the canonical scoped Memory V2
key (and constructs its repository with an authenticated test scope). This is
test-baseline compatibility only; it does not restore or migrate the legacy
Memory key.

### Certification

Focused runtime coverage proves:

- A→B→A isolation, including identical logical IDs, B deletion, and provider
  recreation;
- same-user refresh preserves one A record without duplication;
- signed-out state exposes no authenticated Memory projection, and
  signed-out→B exposes no A memory;
- a rapid later scope starts empty and cannot receive earlier account data;
- scoped read failures and write failure/retry do not use or alter the global
  legacy key; and
- `memories_v1` remains unchanged, unclaimed, and unhydrated.

`siStateAggregationProvider` directly watches `memoriesProvider` and passes
that value into `SIStateAggregation.memories`. The Memory-derived aggregate
input is therefore certified by the real provider handoff proof: A-only Memory
is visible under A, absent under B, B-only Memory is visible under B, and A is
restored on return. Full SI aggregation remains deferred: unrelated aggregate
inputs and global `si_engine_workspace_v1` are outside FIX-004C1 and require
the follow-on workspace repair.

The final closure suite includes FIX-004B, FIX-004A, FIX-001/002/003, and
Root-05 regressions, plus targeted analysis and detached exact-index
validation.
