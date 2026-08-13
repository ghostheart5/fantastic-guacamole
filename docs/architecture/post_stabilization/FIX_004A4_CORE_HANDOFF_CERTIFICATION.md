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
