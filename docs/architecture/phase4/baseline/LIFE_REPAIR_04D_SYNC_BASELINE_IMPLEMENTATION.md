# LIFE-REPAIR-04D — Sync baseline implementation gate

## Result

**BLOCKED before production candidate construction.** No sync production source,
test, lifecycle source, or HLM-06 entry was staged or modified in this phase.

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
