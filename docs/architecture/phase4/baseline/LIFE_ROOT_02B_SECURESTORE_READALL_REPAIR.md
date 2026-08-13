# LIFE-ROOT-02B — SecureStore enumeration repair

## Selected change

`STORE-READALL-H01` restores the sole snapshot-verified
`SecureStore.readAll(): Future<Map<String, String>>` façade hunk. HEAD had no
equivalent API. The selected implementation enumerates the real secure-storage
backend, returns an immutable snapshot for the in-memory backend, and rejects
unknown backend implementations explicitly.

## Deliberate boundary

`SecureStoreBackend` is unchanged. Adding enumeration to that interface would
force unrelated test-double implementations to change and would not match the
Phase 2 façade design. No cleanup, lifecycle, DI, migration, or monetization
source is changed. Caller filtering remains entirely in the existing cleanup
and lifecycle code.

## Security

The method is trusted global enumeration for internal lifecycle/storage code.
It performs no logging, export, filtering, deletion, or key transformation.
The cleanup caller remains responsible for preserving cipher material, retained
session state, and explicitly exempt keys.

## Validation

Focused tests cover empty and multiple-entry enumeration, value preservation,
immutable snapshots, deletion visibility, existing reads, and repeated
non-mutating reads. Targeted analysis proves the lifecycle and cleanup callers
resolve the restored façade without caller edits.
