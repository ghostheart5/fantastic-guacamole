# LIFE-REPAIR-04C — Changed-file sync boundary isolation

## Result

Both changed-file boundaries are exact. **POST-SNAPSHOT REQUIRED
DEPENDENCIES: 0.** The next action is
**READY-FOR-MULTIFILE-SYNC-IMPLEMENTATION**; this is a boundary decision only,
not authorization to stage the sync repair in this phase.

## Profile controller three-way comparison

| Version | Identifier |
| --- | --- |
| HEAD blob | `c2b6bb0e40b2111fedeea3c32c121e92a68ec999` |
| Phase 2 SHA-256 | `42586c7e723f7a7965540f8d5a236a554e8231204c712bbb465570829bfea0b7` |
| Current SHA-256 | `017fa008655b58a1578656cc51cc0243911524f51edbdd0ae5d6c23c336e1132` |
| HEAD → snapshot raw hunks | 13 |
| Snapshot → current raw hunks | 13 |

Current differs from snapshot solely because of later HLM-05 progression work:
the progression-calculator import, `legacyLevelFloor`, JSON evolution, and
progression calculations. None is required by sync.

| ID | Region | Classification | Candidate treatment |
| --- | --- | --- | --- |
| PROFILE-SYNC-H01 | `secureStorageKeyForUser(String?)` | REQUIRED-SNAPSHOT-SYNC | add to current HEAD, using current `_secureStateKey` as the equivalent base key |
| PROFILE-SYNC-H02 | `_safeStorageScope(String?)` | REQUIRED-SNAPSHOT-SYNC | add beside H01, preserving snapshot normalization semantics |
| PROFILE-SYNC-H03 | Phase-2 scoped hydration/migration/write-drain regions | SHARED-BOUNDARY | excluded from sync candidate; no SyncActions method directly calls them |
| PROFILE-SYNC-H04 | all 13 snapshot→current progression hunks | POST-SNAPSHOT-UNRELATED | exclude |

The future candidate is **current HEAD** plus H01/H02 only. It does not copy a
snapshot file and therefore preserves committed HLM-05 progression behavior.
`f1d3d072` is the committed HLM-05 staged candidate in the current ancestry;
starting at current HEAD preserves it automatically. HLM-05 preservation:
**PASS**.

## Domain-provider three-way comparison

| Version | Identifier |
| --- | --- |
| HEAD blob | `af4e8fb2e43848ef352e5cc7e4b0fe2e03ef0bbf` |
| Phase 2 SHA-256 | `f1022f34ba6e32c16b253d4430e44dcb4c8a884781e31b89a3008e41009e9feb` |
| Current SHA-256 | `d876d34d735364d70b891c73d8648c49a3e635ff42fdb6fa0037c50399aa3364` |
| HEAD → snapshot raw hunks | 2 |
| Snapshot → current raw hunks | 2 |

The sole post-snapshot semantic change removes `dart:convert` and storage
imports. It is POST-SNAPSHOT-UNRELATED and does not affect sync compilation.
The actual `syncQueueStoreProvider` is in
`data/di/repositories_providers.dart`, not this file.

| ID | Region | Classification | Candidate treatment |
| --- | --- | --- | --- |
| DOMAIN-SYNC-H01 | `domainTaskRepositoryProvider` consumed by backup construction | HEAD-ALREADY-SUFFICIENT | no domain candidate hunk |
| DOMAIN-SYNC-H02 | post-snapshot import removal | POST-SNAPSHOT-UNRELATED | exclude |

The domain candidate is **E — NOT INCLUDED**: current HEAD already supplies the
only referenced provider. This corrects the earlier 11-file manifest: the
minimum sync repair set is **10 files**, not 11.

## Candidate sources and test impact

Profile candidate construction: current `HEAD:profile_controller.dart` plus
the two deterministic static helper regions proven above, with snapshot only as
semantic evidence. Domain has no candidate construction. Tests must prove that
existing committed progression behavior is unchanged, the scoped profile key
has the snapshot normalization behavior, backup can resolve it, and the
existing domain task provider remains available without unrelated provider API
changes.

No unresolved shared boundary remains in either changed file. The 17-case sync
matrix remains required for the later multi-file implementation.
