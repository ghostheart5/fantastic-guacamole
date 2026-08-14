# FIX-004A4 core account handoff certification

Starting committed baseline: `ae8104046641814a816b6b63e284177d403979ad`.

## Core V2 storage map

| Family | Repository provider | Active storage authority | Legacy/global status | Lifecycle owner |
| --- | --- | --- | --- | --- |
| Tasks | `taskRepositoryProvider` | encrypted Hive `tasks_box.v2.<encoded raw user ID>` | base `tasks_box` preserved and unclaimed | drain + invalidate |
| Goals | `goalRepositoryProvider` | encrypted Hive `goals_box.v2.<encoded raw user ID>` | base `goals_box` preserved and unclaimed | drain + invalidate |
| Habits | `habitRepositoryProvider` | encrypted Hive `habits_box.v2.<encoded raw user ID>` | base `habits_box` preserved and unclaimed | drain + invalidate |
| Plans | `planRepositoryProvider` | encrypted Hive `daily_plans_box.v2.<encoded raw user ID>` | base `daily_plans_box` preserved and unclaimed | drain + invalidate |
| Timeline | `timelineRepositoryProvider` | `timeline_events_v2.<encoded raw user ID>` in `SensitivePrefsStore` | `timeline_events_v1` preserved, inactive, unclaimed | invalidate repository and `viewTimelineUsecaseProvider` |
| CompletionEvent | `completionEventRepositoryProvider` | `completion_events_v2.<encoded raw user ID>` in `SensitivePrefsStore` | `completion_events_v1` preserved, inactive, unclaimed | invalidate repository and read model |

`accountStorageScopeProvider` is the single local namespace authority. It
watches the authenticated user and session boundary, supplies a collision-free
`v2.<encoded raw user ID>` namespace only when authenticated/ready, and returns
unsafe with no namespace during a transition.

## Confirmed prior evidence

Existing A1/A2/A3 repository matrices cover per-family V2 isolation, unsafe
instances, V1 non-claim/preservation, restart/rehydration, and scoped failure
no-fallback. A3 also proves Timeline/Completion provider handoff, Timeline
read-chain recreation, SI dependency isolation, and real complete/delay/skip
Timeline writes.

The established Root-05 ordering remains suspend, drain, invalidate,
scope/migration/bootstrap, ready, resume. The lifecycle drains Task, Goal,
Habit, and Plan repositories before invalidation; Timeline and Completion own
no independent write queue/tail.

## A4 stale Task/Goal domain adapter repair

`test/state/providers/core_account_handoff_stale_adapter_audit_test.dart`
proves the smallest failing boundary. The lifecycle invalidates
`taskRepositoryProvider` and `goalRepositoryProvider`, and those provider
instances recreate. However, `domainTaskRepositoryProvider` and
`domainGoalRepositoryProvider` construct with `ref.read` and are not
invalidated by `AuthSessionLifecycleCoordinator._invalidateIdentityOwnedState`.
They remain object-identical across the simulated A-to-B repository handoff.

This violated the A4 requirement that every cached account-owned chain either
watches `AccountStorageScope` or is explicitly invalidated. Downstream cached
Task/Goal use cases also use `ref.read` from these domain adapters.

Selected bounded repair in `AuthSessionLifecycleCoordinator`'s existing
invalidation phase: invalidate `domainTaskRepositoryProvider`,
`domainGoalRepositoryProvider`, Task read/create/complete/update use cases,
and Goal read/create/update/delete/complete use cases. These are the current
cached providers reached by `tasksProvider`, `taskActionsProvider`,
`goalsProvider`, and the Goal notifier's current create/update/delete/complete
paths. Task/Goal actions themselves keep only `Ref`; they do not cache a
repository and need no separate invalidation. No storage, lifecycle order,
authentication, or unrelated feature semantics changed.

The updated runtime probe proves repositories, domain adapters, and every
selected use case are object-distinct after the simulated A-to-B invalidation
set. The pre-repair condition is retained in this document as discovery
evidence; focused test and analyzer results are PASS pending exact-index and
post-commit validation.

## Certification result

FIX-004A4-PRE-REPAIR is in validation. The full A4 scenario remains deferred;
Profile/Learning/Settings/ExtendedDomain remain out of scope.

## A4-01A mixed-backend runtime harness

`test/state/providers/core_six_family_harness_test.dart` reuses the existing
account-scoped repository providers with one temporary Hive backend for Task,
Goal, Habit, and Plan plus one in-memory `SharedPrefsStore` for Timeline and
CompletionEvent. The harness overrides only `accountStorageScopeProvider`,
`hiveStoreProvider`, and `sensitivePrefsStoreProvider`; production repository
construction and scoped-key logic remain real.

Its smoke test constructs all six repository providers under ready account A,
writes and reads one record through each active backend, accesses Task/Goal
domain adapters and the Timeline view-use-case, and rebuilds a ProviderContainer
against the same persisted test storage. The Plan fixture uses an empty,
contract-valid `blocks` list. Smoke test and targeted analysis PASS. The test
does not yet assert A-to-B isolation, provider recreation, or any later A4
batch.

## A4-01B Plan discrepancy diagnosis

The first A4-01B harness driver invalidated `planRepositoryProvider` but
omitted the remainder of the existing Plan lifecycle invalidation set:
`domainPlanRepositoryProvider`, `getPlanUseCaseProvider`,
`createPlanUseCaseProvider`, and `updatePlanUseCaseProvider`. That incomplete
driver observed an A Plan after the simulated A-to-B change; it was not a valid
reproduction of the committed lifecycle.

The Plan-only diagnostic uses the complete current lifecycle set. It proves a
distinct B repository instance, an empty B V2 `daily_plans_box`, and `null`
from the repository, domain adapter, and `GetPlan` use case. `PlanRepository`
has no in-memory Plan cache, compatibility fallback, or alternate storage read:
`getPlan` opens only its constructor-bound V2 `HiveStorage` and reads the date
key. No Plan notifier/read model participates in this repository path.

Conclusion: no production Plan handoff repair is proposed. The A4-01B harness
must retain the complete already-committed Plan invalidation set before its
integrated six-family certification is resumed.

## A4-01B DIAG-02 delta matrix

The Plan-plus-Task, Goal, Habit, all pairwise, Hive-core, Timeline, and
Completion combinations all return `null` for B Plan storage, repository,
domain adapter, and `GetPlan`, both when Plan is read first and after the other
family reads. The same result holds with the original `a4-a`/`a4-b` scopes and
the full harness's extra shared Task/Goal records. No override collision, box
name collision, date-key issue, wrong container, or Hive lifecycle issue was
observed. The earlier full-case failure is therefore not reproduced by the
requested delta matrix; classification remains harness/fixture UNKNOWN, not a
production defect. A4-01B remains blocked pending diagnosis of the remaining
full-fixture sequence.

## A4-01B DIAG-03 original-fixture differential

The original full fixture fails alone in a fresh Flutter test process, while
the reconstructed fixture passes. The following original-only operations were
then replayed against the reconstructed setup without reproducing the stale
Plan: A/B provider-graph capture and identity comparison, unsafe Task/Timeline
error assertions, the B Task/Goal/Habit absence reads, and the explicit B Plan
box assertions. In every replay, raw B storage remained empty and the B
repository, domain adapter, and `GetPlan` use case returned `null`.

No invalidation-order, early-recreation, retained-object, override,
container, date-key, or Hive-global difference has been demonstrated. The
first divergent checkpoint remains the original fixture's own B Plan assertion,
but its cause is not yet isolated. Classification remains UNKNOWN test fixture;
production behavior is not implicated and no correction is authorized.

## A4-01B DIAG-04 Plan value provenance and fixture correction

The literal failing expression was
`expect(await container.read(planRepositoryProvider).getPlan(DateTime.utc(2026, 8, 13)), isNull)`
inside `_expectOwnerAbsent`. Four-layer logging proved the initial A-to-B Plan
check is correct: B repository/domain/GetPlan/original expression all return
`null` and access `daily_plans_box.v2.YTQtYg==`. The apparent failure occurs on
the later B-to-A return: all four paths return `A_ONLY_PLAN` from the separate
A box `daily_plans_box.v2.YTQtYQ==`.

This is correct scoped behavior. Plan storage is date-keyed within an account,
so A's same-date Plan is required to exist after returning to A. The fixture
incorrectly treated the presence of any Plan on that date as B leakage. The
test-only correction asserts that the Plan ID does not equal the absent
account's `${owner}_ONLY_PLAN` instead. The original full six-family fixture
then passes through B data and the B-to-A restoration path. No production
change is required or authorized.

The corrected full mixed-backend six-family harness passes through the A-to-B
isolation and B-to-A restoration paths. The discrepancy was a fixture
assertion, not a production Plan handoff defect; no production change is
authorized or required.

## A4-02 — Session Transition Safety

Starting authoritative baseline: `8ac8d29cc9e1e62a930424f5bd11858cda98cf65`.
This batch changes no production source. It extends the existing A4-01
mixed-backend harness only, retaining the same `AccountStorageScope` driver,
real repository providers, and current lifecycle invalidation set.

### Results

- Same-user refresh: PASS. A refresh for the same normalized authenticated
  user retains the identical V2 namespace and all six distinct A records.
  Task/Goal domain adapters, `GetPlan`, and the Timeline view use case resolve
  current A data after provider recreation. No signed-out or V1 key is used.
- A → signed-out → B → A: PASS. Signed-out has `isAuthenticated == false` and
  its isolated `v2.signed_out` namespace contains no copied A records. B reads
  zero A records, writes only B V2 state, and returning to A restores A while
  excluding B. The test deliberately does not assert a retention/deletion
  policy for signed-out data.
- Rapid/superseded transition: PASS under the strongest current harness
  simulation: A ready → unsafe/begin B → final C before B becomes ready. The
  final scope is user `a4-rapid-c` and namespace
  `v2.YTQtcmFwaWQtYw==`; all six repository chains and the four cached
  Task/Goal/Plan/Timeline chains are new final-target instances. C contains no
  A records, and the intermediate B target never receives a ready repository.
- Unsafe transition: PASS. Fresh repositories for all six families are
  unavailable while the scope has no V2 namespace; writes fail without an A,
  B, signed-out, or V1 fallback.
- Legacy ambiguity: UNCLAIMED. Same-user, signed-out, and superseded paths use
  no `_v1` keys; the existing A1/A2/A3 matrices remain the authoritative
  byte-preservation evidence for legacy stores.

### Transition-write behavior

| Family | Active write behavior | Root-05 drain | A4-02 boundary result |
| --- | --- | --- | --- |
| Task | serialized async queue | yes | stale A write fails closed; absent from B |
| Goal | serialized async queue | yes | stale A write fails closed; absent from B |
| Habit | serialized async queue | yes | stale A write fails closed; absent from B |
| Plan | serialized async queue | yes | stale A write fails closed; absent from B |
| Timeline | direct scoped-store future; no owned queue | no | retained A instance writes only its A key; absent from B |
| CompletionEvent | direct scoped-store future; no owned queue | no | retained A instance writes only its A key; absent from B |

The Timeline and Completion rows are intentionally classified rather than
given an invented drain contract: their repositories bind a scoped storage key
at construction and Root-05 does not own an independent tail for either.

Focused certification reran the A4-01 harness plus Task/Goal, Habit/Plan,
Timeline/Completion, stale-adapter, scope/boundary, lifecycle activation,
legacy migration, Root-05 dispatch/recovery, and Insights invalidation suites:
59 prior regression tests plus 11 harness tests passed. Targeted analysis is
clean. The remaining A4 batch is A4-03, limited to SI/read-context isolation,
Nexus/Smart Planner/Trajectory core inputs, and a cross-family B mutation;
none of that work begins here.

## A4-03 — Core Read Context and B Mutation Certification

This batch is **PASS** for its authorized core input boundary. The direct,
runtime-testable SI dependency object proves current account isolation for its
actual core inputs: Task, Goal, Plan, and Timeline.
`timelineProvider` and `completionEventsProvider` also resolve only the current
account in the same A-to-B harness. B mutation proof passes for all six
repositories and B-to-A restoration excludes B records.

Full `siStateAggregationProvider` certification is **DEFERRED TO FIX-004B/C**.
It is a mixed-scope composition boundary and cannot be validly certified in
this isolated core-family harness without overriding Profile, Learning,
Settings, ExtendedDomain, durable SI/memory, and platform-backed
notification/secure-storage dependencies. Those overrides would be surrogate
evidence rather than a runtime proof of the aggregate. Its Task input reaches
`tasksProvider`, which requires optimization/Profile/Learning state; its Goal
input reaches `goalsProvider`; Timeline is direct. The committed lifecycle does
invalidate `tasksProvider`, `goalsProvider`, `timelineProvider`,
`completionEventsProvider`, and `siStateAggregationProvider`.

Current source maps: SI engine dependencies consume Task, Goal, Plan, and
Timeline directly; the SI pipeline's planner input is Task-only and also reads
Goal/Timeline; Nexus directly reads ranked Tasks (with its screen model using
the SI aggregation); Smart Planner is fed by the pipeline's Task planner input;
Trajectory reads ranked Tasks and Future Timeline reads Completion events.
Habit has no direct input in these currently wired paths. No production defect
or change is proposed. The `unnecessary_import` info in
`si_pipeline_provider.dart` is pre-existing, was not introduced by A4-03, and
is not a certification blocker. Full FIX-004A1/A2/A3, FIX-001/002/003, and
Root-05 regression replay is deferred to A4-04 final certification.

## A4-04 — Final Core Planning/History Handoff Certification

The final A4 harness proves normal destructive operations are account-local:
Task `deleteTask`, Goal `deleteGoal`, Habit aggregate replacement with an empty
list, Timeline `removeEvent`, and Completion `removeEvent` affect only B.
Plan has no ordinary delete/clear API; its scoped destructive equivalent is
replacement by date. Replacing B's same-date Plan leaves A's same-date Plan
unchanged. `timeline_events_v1` and `completion_events_v1` remain byte-for-byte
unchanged.

Account deletion and explicit cleanup helpers are whole-account/destructive
operations and are not normal feature deletion. The six active core stores are
separate V2 account namespaces: encrypted Hive `tasks_box`, `goals_box`,
`habits_box`, and `daily_plans_box` suffixed with `v2.<encoded-user>`; and
SensitivePrefs `timeline_events_v2.<namespace>` and
`completion_events_v2.<namespace>`. No active core family reads a global/V1
store. All six legacy sources remain preserved and unclaimed.

The final provider handoff map is: Task repository/domain/use cases; Goal
repository/domain/use cases; Habit repository; Plan repository/domain/GetPlan
and write use cases; Timeline repository/view use case/read model; and
Completion repository/read provider. The lifecycle drains Task, Goal, Habit,
and Plan queues before invalidation, then invalidates these cached chains.
Timeline and Completion are constructor-scoped direct stores with no owned
queue. Existing scoped failure matrices cover Hive and SensitivePrefs failures
without global, V1, or signed-out fallback; unsafe-scope and superseded-target
proofs remain PASS.

Final focused regression replay: 59 prior A1/A2/A3/lifecycle/Root-05 cases
plus 14 A4 harness cases pass. Full mixed SI aggregation, Profile, Learning,
Settings, ExtendedDomain, durable SI/memory, and platform-backed account
behavior remain deferred to FIX-004B/C. **Core Planning/History handoff is
certified; full Wave 1 is not.**
