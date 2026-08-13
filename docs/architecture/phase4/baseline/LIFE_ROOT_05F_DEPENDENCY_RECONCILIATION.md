# LIFE-ROOT-05F — implementation dependency reconciliation

This supersedes LIFE-ROOT-05D only for dependency selection.

## Dispatcher constructor

`SyncMutationDispatcher` HEAD constructor accepts `queueStore`, optional
Supabase client, and a `userIdResolver`. The selected candidate uses required
captured `userId`, a cancellation gate, and an operation tail. Capturing the
provider-resolved user ID prevents a delayed resolver from observing B after A
work was accepted.

Production caller: `data/di/repositories_providers.dart`, selected
`DISPATCH-CALL-H01` (construct with `userId`, dispose dispatcher). Two test
constructor callers are selected as validation updates; no lifecycle caller is
modified. The provider is the canonical scope authority.

## Recovery constructor

`SessionRecoveryService` HEAD is zero-argument. The candidate requires
`storageScope`, namespaces recovery keys, gates its mutation tail, and exposes
`cancelAndDrain`. Production caller: `state/providers/session_recovery_provider.dart`,
selected `RECOVERY-CALL-H01`: watch `AuthSessionBoundary`, supply
`boundary.userId ?? 'signed_out'`, and dispose the service. This is the single
scope-normalization source; lifecycle only reads the provider.

## Complete repository drain selections

Task requires five inseparable groups: `TASK-DRAIN-H01` fields/drain/dispose;
`H02` save serialization; `H03` delete serialization; `H04` serializer gate;
and `H05` failure-safe write-tail maintenance. Habit requires two groups:
`HABIT-DRAIN-H01` fields/drain/dispose and `H02` serialized save/helper gate.
Goal requires all three groups: `GOAL-DRAIN-H01` fields/drain/dispose,
`H02` serializer gate, and `H03` failure-safe tail. Thus Task, Habit, and Goal
are self-contained only with these complete sets; no unknown hunk is selected.

## Superseding closure

The revised production manifest is **15** modified files (the prior 13 plus
the dispatcher and recovery provider callers), one required-no-change
`sync_provider.dart`, and the validation-only untracked lifecycle source.
Selected implementation groups total **24**: prior Profile/Settings and
Root-05D groups, plus six newly explicit repository groups and two caller
groups. All fourteen diagnostics remain covered; selected external
dependencies: zero; unknown selected: zero.

Use pre-repairs first: **ROOT05-PRE-01** dispatcher constructor/provider and
its tests; **ROOT05-PRE-02** recovery constructor/provider and its tests. Then
perform the dependency-ordered Root-05 drain, adapter, and identity/invalidation
commits. Future tests add captured dispatcher scope, cross-user dispatch,
recovery scope isolation/default scope, and Task/Habit queued/failure/repeat
drain coverage, bringing the planned matrix to **25** tests.

**Next action: READY-FOR-ROOT05-PRE-REPAIRS.**
