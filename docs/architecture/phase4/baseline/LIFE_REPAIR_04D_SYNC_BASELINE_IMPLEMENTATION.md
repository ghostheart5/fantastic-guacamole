# LIFE-REPAIR-04D — Sync baseline implementation gate

## Result

**BLOCKED before production candidate construction.** No sync production source,
test, lifecycle source, or HLM-06 entry was staged or modified in this phase.

## LIFE-REPAIR-04F implementation result

The superseding 04E map authorized one atomic five-file candidate. The staged
blobs are `b1c3041e17766595131f92f5a7cdf8491effd7d0`
(`sync_provider`), `193b275f2386982cbbb4fa72752ec83b6ab08e61`
(`sync_service`), `31c457e2309f02fd630ce4ef690815447fa3519c`
(`offline_sync_queue_service`), `20befa8173b5999103aabbd8369c787801528feb`
(`backup_service`), and `ca189887bf93d440c218e7808792adff6b9a6037`
(`profile_controller`).

The Profile candidate is exactly current HEAD plus `PROFILE-SYNC-H01/H02`.
Forensic review rejected a formatter-produced unrelated HLM-05 whitespace
change and restored the two-helper-only blob. No required-but-no-change file
was staged.

An exact-index sandbox with the untracked lifecycle consumer resolved all
syncActionsProvider/cancelAndDrain diagnostics. Its remaining 23 diagnostics
are separate previously mapped BASE-03 roots (monetization source, secure-store
enumeration, migration, repository drains, identity/invalidation APIs). The
available sync integration test could not load because of unrelated committed
SI/decision/planner baseline compilation defects; it did not reach the sync
test cases. This limitation is recorded separately from the resolved sync root.

## Superseding manifest clarification (LIFE-REPAIR-04E)

The ambiguity described below is resolved by the authoritative selected-hunk
ledger: dependency manifest count **11**; production modified-file count **5**.
`domain_usecase_providers.dart` is REQUIRED-BUT-NO-CHANGE. See
`LIFE_REPAIR_04E_SYNC_SELECTED_HUNK_MAP.md` for the superseding boundary.

## Conflicting implementation scope

LIFE-REPAIR-04D requires the “exact 11-file manifest” from 04B. The later,
authoritative 04C isolation proves that
`domain_usecase_providers.dart` has no required sync candidate hunk: its
already-committed `domainTaskRepositoryProvider` is sufficient and the actual
`syncQueueStoreProvider` belongs in `repositories_providers.dart`. 04C thus
correctly reduces the future candidate to 10 files and explicitly requires no
domain-provider change.

The instruction to use an exact 11-file manifest while excluding the same
domain file has no unambiguous commit boundary. Treating the obsolete 11-file
entry as authorization would violate 04C; silently choosing 10 would contradict
04D's stated manifest requirement.

## Missing forensic boundary

04B reports 95 raw HEAD-to-current hunk groups across the snapshot-verified
files, but explicitly leaves the remaining groups for candidate-level
accounting. It provides required semantic groups, not an exact file-by-file
selected-hunk map. 04D requires every staged production line to map to a named
LIFE-REPAIR-04 category and forbids staging whole protected dirty files.

Accordingly, a deterministic multi-file candidate cannot yet be proven to
exclude unrelated protected work. Constructing it now would either copy broad
snapshot files or make unrecorded hunk selections, both outside the governing
contract.

## Required resolution before implementation

1. Reconcile the manifest explicitly: adopt the 10-file set or identify a
   concrete required domain-provider symbol absent from HEAD.
2. Produce per-file selected raw-hunk maps for every candidate file, including
   all required imports and direct consumer delegation.
3. Classify each unselected raw hunk as excluded, shared, or independently
   committed before external candidate blobs are built.
4. Reconfirm the resulting selected set in an exact-index sandbox before any
   production commit.

Until then, the only valid next state is a controlled boundary-mapping phase;
the lifecycle provider and HLM-06 remain out of scope.
