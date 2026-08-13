# FIX-004A3 test harness

## PRE-TEST-02A — repository persistence evidence

`test/data/repositories/timeline_completion_account_scope_repository_test.dart`
provides a test-only `SharedPrefsStore` with inspectable values and deterministic
read/write failures. It uses `AccountStorageScope.authenticated` for the actual
V2 namespace contract and `unavailable` repository constructors for unsafe
transition checks.

The Timeline and Completion matrices cover A/B isolation, same-ID coexistence,
remove isolation, repository recreation, unsafe scope, preserved/inactive V1,
read/write no-fallback, and same-user stability. The existing namespace suite
supplies the 516-identity collision proof. Provider handoff, SI/read context,
and command regression evidence remain later PRE-TEST phases.

## PRE-TEST-02B — provider handoff and A→B→A integration

`test/data/repositories/timeline_completion_provider_handoff_test.dart` drives
the real repository providers through a `ProviderContainer`, with only the
scope and sensitive-store dependencies overridden. It applies the two exact
FIX-004A3 repository invalidations at each simulated account transition.

The test proves that both provider instances are recreated for A→B and B→A;
B initially observes neither of A's records; and returning to A observes only
A's prior Timeline and Completion records. No production lifecycle or provider
code was changed while collecting this evidence.

## PRE-TEST-02C — SI/read-context isolation

The selected read paths are `timelineProvider` (consumed by
`siPipelineProvider`), `completionEventsProvider` (consumed by
`intelligenceFusionProvider`), and `siEngineDependenciesProvider` (the input
to `StateSiEngineService`). The runtime test confirms that the direct SI
dependency snapshot and the Completion read model exclude A after the exact
repository/read-model invalidations.

Before the bounded repair, the Timeline read-model assertion failed: after A
was read and the scope transitioned to B, invalidating
`timelineRepositoryProvider` and `timelineProvider` still returned A's event.
The exact active chain is `timelineProvider` →
`viewTimelineUsecaseProvider` → `timelineRepositoryProvider`. Both provider
edges use `ref.read`, so the cached view use case retained the A-scoped
repository. `domainTimelineRepositoryProvider` is not in this failing chain
and was deliberately excluded.

The authorized repair adds only `viewTimelineUsecaseProvider` to the existing
session invalidation set, immediately after `timelineRepositoryProvider` and
before the existing `timelineProvider` invalidation. It changes neither
transition ordering nor Timeline storage behavior.

After repair, the runtime test proves that the view use-case instance is
recreated and that B's Timeline read model is empty after A→B. The selected SI
runtime context (`siEngineDependenciesProvider`, the input to
`StateSiEngineService`) and Completion read context also exclude A. The SI
pipeline consumes `timelineProvider` with `ref.watch`; the repaired Timeline
runtime boundary therefore provides its B-scoped Timeline input without any SI
logic change.

PRE-TEST-02C is now PASS. Command regression, failure-injection, exact-index
certification, and commit remain deferred to PRE-TEST-02D / FIX-004A3 FINAL.

## PRE-TEST-02D — failure and regression certification

`test/data/repositories/timeline_completion_failure_scope_test.dart` covers
FI-TL-01 through FI-TL-04 and FI-CE-01 through FI-CE-04. Injected read and
write failures surface through the existing repository contract, never read or
write V1 keys, preserve prior scoped values, and leave a subsequently-created
B repository isolated. Rebuilding A after a failed write remains repeat-safe.

Timeline and Completion repositories have no owned mutation queue, pending
tail, or drain API: each operation reads synchronously and returns the direct
`SharedPrefsStore.save` future. The transition-during-pending-operation case is
therefore not applicable; no artificial asynchronous behavior was added.

Existing command regressions exercise task completion orchestration and the
release transition-chain contract for completion, delay/reschedule, and skip.
They retain the current persistence-before-invalidation and Timeline fan-out
paths. The existing goal orchestration regression proves a representative goal
create action fans out to Timeline. No command, SI, or fan-out semantics were
changed for A3.

The exact-index candidate was constructed from `d839b1c5364fab671ef5a3220b432e9cc18ad2c0`
plus only the four authorized production files, these two documents, and the
three A3 test files. A blank ignored `.env` was created only inside that
validation worktree because Flutter declares it as an asset; it is not a
candidate file and is not committed. The exact candidate passed 74 focused
tests and targeted analysis with zero diagnostics. Its index has only those
nine approved paths, `git diff --check` is clean, and it has no untracked
source dependency.

Command evidence is deliberately bounded: task-complete and representative
goal-create execute their current orchestration paths and Timeline fan-out;
delay/reschedule and skip are guarded by the existing current-path release
contract. Account-scoped destination, legacy non-claim, and A-to-B isolation
are proven by the real Timeline/Completion repository and provider-handoff
tests, without changing command semantics or adding a synthetic product path.

This is not yet the strict end-to-end command-to-real-V2-destination proof
required for the FINAL gate: the command tests use their existing Timeline
action seam, and delay/skip are current-path contract tests. PRE-TEST-02D is
therefore BLOCKED pending a test-only adapter that drives complete, delay, and
skip through that seam into a real scoped Timeline repository and verifies an
A-to-B read boundary. No production change is authorized or required by this
gap.

## PRE-TEST-02E1 — complete command real V2 proof

`test/data/repositories/timeline_complete_command_v2_test.dart` invokes the
real `TaskActions.completeTask` path through the un-overridden Timeline action,
notifier, creation use case, and scoped `TimelineRepository`. Only task state,
profile state, and the in-memory `SharedPrefsStore` test backend are supplied.
It proves the completed-task history record is stored at account A's actual
`timeline_events_v2.<namespace>` key, absent for B after a rebuilt container,
available again on return to A, and leaves the seeded `timeline_events_v1`
sentinel byte-for-byte unchanged. CompletionEvent tracking is not exercised:
the current flag disables that optional fan-out in this harness.

## PRE-TEST-02E2 — delay and skip real V2 proof

The same real-provider harness invokes `TaskActions.delayTask` and
`TaskActions.skipTask`. Both travel through `timelineActionsProvider`,
`TimelineNotifier.record`, the Timeline creation use case, and the real scoped
repository. The delay test writes `Task Delayed` under A's V2 key, is absent
when B is rebuilt, and returns on A rebuild. A B-owned skip then writes `Task
Skipped` only under B's V2 key while A's delay history remains intact. The V1
sentinel is unchanged throughout. CompletionEvent tracking remains not
exercised because the existing optional flag is disabled; no fan-out was added.

## FIX-004A3 final certification

Starting HEAD was `d839b1c5364fab671ef5a3220b432e9cc18ad2c0`. The final
candidate contains exactly four production files, the four A3 tests listed
above, and these two A3 documents. Timeline authority is
`timeline_events_v2.<AccountStorageScope.v2Namespace>` and Completion authority
is `completion_events_v2.<AccountStorageScope.v2Namespace>`. The V1 Timeline
and Completion stores are intentionally ambiguous, preserved, inactive,
unclaimed, and not migrated or deleted.

The final exact-index candidate passed 76 focused tests with zero failures and
targeted analysis with zero diagnostics. It has no untracked source dependency;
the blank validation-only `.env` is ignored, unstaged, and uncommitted. The
repository/provider matrices prove storage and A-to-B-to-A handoff; the
Timeline read-chain test proves the stale cached view-use-case repair and its
SI/read-context isolation. Failure-injection, namespace collision, Task/Goal,
Habit/Plan, readiness, lifecycle, sync, recovery, Learning, and Reminder
regressions all passed. PRE-TEST-02D and PRE-TEST-02E are PASS.
