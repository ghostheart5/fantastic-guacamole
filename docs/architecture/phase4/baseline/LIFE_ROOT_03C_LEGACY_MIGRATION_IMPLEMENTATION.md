# LIFE-ROOT-03C — Legacy Migration / Scoped-Key Repair

## Scope

This repair restores the four selected Root-03 semantics across three files:
the two `ExtendedDomainService` migration members, the Profile migration
helper, and the Learning migration helper. The existing
`ProfileController.secureStorageKeyForUser` contract is unchanged.

## Migration invariants

- A pre-existing scoped destination is authoritative and is never overwritten.
- An absent legacy source is a no-op.
- A legacy source is removed only after the destination write succeeds.
- A failed write retains the source for retry.
- A completed migration is idempotent because its destination then exists.

Profile tries the legacy secure-store state before its legacy Hive state; both
write to the established `profile_state_v2.<scope>` key.

## Candidate construction note

03C's zero-context patches were rejected by exact-index analysis because they
could land outside their classes. 03D reconstructs candidates from HEAD in a
detached worktree, applies members at explicit class-member anchors, formats
only those candidate files, and analyzes each file before any index update.

## Final candidate evidence

- ExtendedDomain: `38b6e315fe96350b953a549ee36afaf1322b5f32`
- Profile: `010bb5743865c4d57e13248cfa3332f86b9eb416`
- Learning: `e1fd451a3261eb1a5e015e04b1f598bee323a3de`

`test/state/controllers/legacy_migration_contract_test.dart` exercises scoped
key determinism, destination preservation, successful-copy cleanup, failed
copy source retention, repeated migration, user isolation, and the narrow
HLM-05 progression regression. The untracked lifecycle provider is copied
into the disposable exact-candidate worktree solely as a validation overlay;
it is never staged or committed. Its Root-03 API references resolve. Remaining
overlay diagnostics concern later cancel-and-drain and identity-work roots.

The exact-candidate focused suite passed five migration/progression cases, and
the existing `progression_calculator_test.dart` passed five HLM-05 regression
cases. Targeted analysis of the three candidates and the focused test passed
with zero diagnostics. The lifecycle overlay compiled every Root-03 migration
and Profile-key reference; its fourteen remaining diagnostics are outside this
repair's selected semantics.
