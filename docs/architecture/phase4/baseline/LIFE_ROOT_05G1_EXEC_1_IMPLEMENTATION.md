# LIFE-ROOT-05G1 — G0 EXEC-1 implementation

## Authority and scope

G0 manifest: `a8bc4371374519f31bc114c9c68ccbd929f0349e`.
Starting HEAD: `a8bc4371374519f31bc114c9c68ccbd929f0349e`.

This commit implements only G0 `EXEC-1`:

| R05 IDs | Path | HEAD blob | candidate blob |
| --- | --- | --- | --- |
| R05-001…R05-005 | `lib/data/repositories/task_repository.dart` | `acb0da73aaa0084976fd702be5a89318624a7954` | `9b1435163dd8b29384eaba266b44159d9f853430` |
| R05-006…R05-007 | `lib/data/repositories/habit_repository.dart` | `81e3f5fa7b9767f1bccaffeac9126e19728cd4b3` | `94c24fe6436ace9afba5b2d02b7daf433599049e` |
| R05-008…R05-010 | `lib/data/repositories/goal_repository.dart` | `a11a493009da0b20617c143d3bd3b7c2629eae9f` | `46c0d107587f0b9ecabcc1ea8326786768f41c0f` |

Dependencies for all ten R05 IDs: none.  No future-EXEC group is included.
The implementations close admission at method invocation, wait for already
accepted writes, preserve a failure-safe queue tail, and make repeated drains
safe.  The admission point is deliberately before queue scheduling, so a write
accepted before transition drains instead of being discarded by a later gate.

## Tests and validation

`test/data/repositories/root05_exec1_repository_drain_test.dart` maps directly
to G0 T01–T10 / R05-001…R05-010.  Existing
`test/data/repositories/habit_repository_test.dart` remains a serialization
regression check.

Focused test result: 12 passed, 0 failed.  Targeted analysis and the exact
index validation are recorded after staging this exact candidate.

## Isolation

The candidate begins from current HEAD and contains no HLM-06 blobs, lifecycle
provider, Profile/Settings changes, or protected dirty semantics.  The main
worktree's twelve staged HLM-06 entries remain untouched.  `EXEC-2` remains
unimplemented; its G0 dependencies are not affected by this group.
