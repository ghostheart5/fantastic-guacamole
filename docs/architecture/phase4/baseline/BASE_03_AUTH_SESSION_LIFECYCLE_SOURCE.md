# BASE-03 — Auth session lifecycle source-presence audit

## Classification

`lib/state/providers/auth_session_lifecycle_provider.dart` is **authoritative
current source**, but it is not independently committable. Its recommended
BASE-03 action is **D — NEEDS REPAIR BEFORE COMMIT**. BASE-03 is therefore
**BLOCKED** pending an explicit, dependency-closure repair plan.

This is a read-only classification. The provider, its consumers, and HLM-06
were not modified or staged by this audit.

## Provenance

| Item | Value |
| --- | --- |
| Current path | `lib/state/providers/auth_session_lifecycle_provider.dart` |
| Git status | untracked (`??`) |
| Current SHA-256 | `4597114c3ba01a4bde4b60bef37f0d1e7a232f85ee2a91e54cad14e408806976` |
| Size | 55,645 bytes |
| Phase 2 snapshot path | `ChronoSparkRecovery/phase2-20260812-164222/snapshot-root/tree/lib/state/providers/auth_session_lifecycle_provider.dart` |
| Phase 2 snapshot SHA-256 | `4597114c3ba01a4bde4b60bef37f0d1e7a232f85ee2a91e54cad14e408806976` |
| Current equals snapshot | yes |

No commit in reachable history contains this exact path. It is a
snapshot-verified current-worktree successor, not a recoverable committed file.

## Public surface and consumers

The source exports `AuthSessionBoundary`, `authSessionBoundaryProvider`,
`AuthSessionBoundaryNotifier`, `authSessionLifecycleProvider`, and
`AuthSessionLifecycleCoordinator`.

Fourteen current sources directly import it. All are dirty worktree files:
`app_bootstrap`, timeline and onboarding UI, tutorial and mission providers,
app integration actions, state bootstrap, profile and learning controllers,
domain-usecase, creator, optimization, and session-recovery providers.

Only `timeline_screen.dart` is a committed HEAD reference; HEAD has no tracked
provider source, so that committed import is already a source-presence defect.
The current `app_bootstrap.dart` is the actual initialization path: it reads
the coordinator, initializes it with the current user, and uses the boundary to
gate startup. Thus the provider is connected in the current runtime graph, but
not in a self-contained committed baseline.

No committed provider offers equivalent serialized ownership checks, bridge
draining, cleanup orchestration, and broad user-scoped invalidation. The
committed `identity_session_bridge_provider` and `session_recovery_provider`
are narrower supporting mechanisms, not replacements.

## Runtime and safety role

For a user transition, the coordinator serializes operations, marks the
boundary transitioning, suspends bridge session writes, drains identity-owned
work, invalidates identity-owned repositories/providers, and clears the active
identity. Its drain set explicitly includes task, goal, habit, **settings**,
sync-dispatch, recovery, profile/learning writers, bridge mutations, reminders,
and profile hydration.

For a confirmed deletion it runs full cleanup. For a sign-out or account change
it reruns `prepareForSignOut()` after drains. It then validates/updates the
ownership marker, handles signed-out handoff/migration, hydrates the incoming
user, optionally bootstraps state, completes the boundary, and resumes bridge
writes only for a non-null successfully transitioned user. Recovery and
legacy-discard paths also suspend and drain before their destructive boundary.

It therefore is the intended orchestrator of BASE-01 (`suspendSessionWrites`,
`drainMutations`, and conditional `resumeSessionWrites`) and BASE-02
(`prepareForSignOut`). It is material to HLM-06: it calls
`settingsRepository.cancelAndDrain()` before invalidating
`settingsRepositoryProvider`, preventing a prior account's settings operations
or repository instance from publishing into a later account scope.

## Quality and dependency closure

Current-worktree targeted analysis of the file reports **no issues**. There are
no TODO/FIXME/placeholder/debug markers. Source maturity is **COMPLETE WITH
DEBT**: it is implemented and runtime-wired in the current worktree, but its
baseline closure is not committed.

A temporary HEAD-plus-this-one-source sandbox reports 29 issues. They include:

- missing untracked `monetization_session_state_provider.dart`;
- missing APIs supplied only by dirty current sources, including
  `SecureStore.readAll`, legacy migration/profile key APIs,
  `cancelAndDrain` on task/goal/habit/settings/sync/recovery/reminder
  dependencies, profile/learning write drains, identity synchronization, and
  extended-domain/insight/monetization invalidation helpers; and
- missing `syncActionsProvider` and `refreshMonetizationRemoteState` baseline
  exports.

The direct import list has 57 internal sources: 56 exist in HEAD and one is
untracked. The effective closure additionally relies on numerous dirty API
providers; the exact count cannot safely be reduced to a source-file count
without reconstructing their transitive contracts. Consequently this is not a
single-file repair and no preservation commit is justified.

## Required BASE-03 tests after closure is repaired

1. Transition suspends new bridge writes.
2. Accepted bridge writes drain before cleanup.
3. Sign-out preparation follows drains and precedes final transition.
4. Settings and other user-scoped repositories drain and invalidate.
5. Failed/cancelled transitions preserve the documented write-resume behavior.
6. Successful transitions cannot revive stale user scope.
7. Account A to B isolation is deterministic.
8. Repeated/same-user transitions are idempotent.
9. Provider lifecycle/disposal leaves no queued session work.
10. Exactly one lifecycle coordinator is wired at application startup.

## Next safe action

Create a separate closure map for the listed missing APIs and the untracked
monetization source, then decide whether to commit a coherent lifecycle
subsystem or reconstruct a smaller committed boundary. Do not commit this file
alone and do not alter HLM-06 as part of BASE-03.
