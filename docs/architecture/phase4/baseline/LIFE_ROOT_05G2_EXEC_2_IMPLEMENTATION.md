# LIFE-ROOT-05G2 — G0 EXEC-2 implementation

## Authority and scope

Starting HEAD: `c6039f107b8f0e1eb8654f98ad8668256a149885`.
G0 assigns only `R05-011` through `R05-014` to EXEC-2.  Their prerequisites
are already committed: the PRE-01 dispatcher constructor/caller and the
PRE-02 recovery constructor/caller.  No dependency is unknown, staged-only,
protected-untracked production source, or assigned to a future EXEC phase.

| R05 IDs | Path | HEAD blob | candidate blob |
| --- | --- | --- | --- |
| R05-011…R05-013 | `lib/data/sync/sync_mutation_dispatcher.dart` | `39a75e3ddc8435ec7695d4c58646d0fd13980683` | `c9d5a119085097b230a344c1298b53ca4590584d` |
| R05-014 | `lib/state/services/session_recovery_service.dart` | `64a12a6312e85af4c0e27886dc053aeb816885df` | `b0d6bb672b784021a9f244963c02958b7a1f9b8c` |

Dispatcher work establishes cancellation state, an operation tail, serialized
enqueue behavior, repeat-safe drain/dispose, and a captured-user session gate.
The no-client test seam retains the PRE-01 fixed user-id behavior; a supplied
client must still match that captured user.

Recovery work establishes one inseparable `RECOVERY-H01`: cancellation gate,
mutation tail, serialized recovery mutation methods, repeat-safe drain/dispose,
and load-after-tail behavior.  It deliberately excludes storage-scope
normalization changes; those are outside EXEC-2.

## Tests and validation

New direct mapping: `test/data/sync/root05_exec2_dispatch_recovery_test.dart`
implements G0 T11–T14.  It covers dispatcher serialized settlement,
transition gating/fixed scope, failure-tail recovery, and non-destructive
scoped recovery drain.

The focused exact-candidate suite collected 19 tests and passed all 19:

- G2 direct T11–T14;
- existing dispatcher constructor/scope tests;
- PRE-02 recovery-scope tests; and
- G1 T01–T10 repository-drain regression.

Targeted analysis, exact-index validation, and cached-diff checks are recorded
after staging the two production candidates, G2 test, and this record only.

## Lifecycle overlay and follow-on readiness

The protected lifecycle overlay directly calls
`SyncMutationDispatcher.cancelAndDrain` and
`SessionRecoveryService.cancelAndDrain`.  Both signatures resolve statically.
No lifecycle file was copied, edited, staged, or committed; no temporary
boundary rewrite was necessary for this API check.

EXEC-3 has no dependency on a future phase in G0.  Its two provider helpers
depend only on the same EXEC service candidate, so it is ready after this
commit.  HLM-06 remains a separately preserved 12-entry staged candidate.
