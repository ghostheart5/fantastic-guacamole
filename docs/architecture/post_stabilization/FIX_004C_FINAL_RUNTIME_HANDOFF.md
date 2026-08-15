# FIX-004C — Durable SI Memory Runtime Handoff

## FIX-004C1 — Memory V2 account authority

### Defect and authority

The prior active Memory authority was the global `memories_v1` key. That
allowed a `MemoryRepository` instance and its `memoriesProvider` projection to
read authenticated content without an account namespace.

The canonical authenticated authority is now
`memories_v2.<AccountStorageScope.v2Namespace>`. `MemoryRepository` requires
an authenticated, ready `AccountStorageScope`; unsafe, transitioning, and
signed-out scopes fail closed and never fall back to `memories_v1`.

`memories_v1` is a legacy, ownership-ambiguous record. It is preserved,
inactive, unclaimed, unhydrated, and never deleted by this repair.

### Provider handoff

`memoryRepositoryProvider` watches `accountStorageScopeProvider`.
`domainMemoryRepositoryProvider` watches the repository provider, and all
Memory get/save/delete use-case providers watch the domain repository.
`MemoriesNotifier.build` watches `getMemoriesUseCaseProvider`. This makes the
repository, use cases, and `memoriesProvider` projection recreate for a new
account scope rather than retaining A-owned state in B.

### Compatibility correction

The corrupt-snapshot repository test now seeds the canonical scoped Memory V2
key (and constructs its repository with an authenticated test scope). This is
test-baseline compatibility only; it does not restore or migrate the legacy
Memory key.

### Certification

Focused runtime coverage proves:

- A→B→A isolation, including identical logical IDs, B deletion, and provider
  recreation;
- same-user refresh preserves one A record without duplication;
- signed-out state exposes no authenticated Memory projection, and
  signed-out→B exposes no A memory;
- a rapid later scope starts empty and cannot receive earlier account data;
- scoped read failures and write failure/retry do not use or alter the global
  legacy key; and
- `memories_v1` remains unchanged, unclaimed, and unhydrated.

`siStateAggregationProvider` directly watches `memoriesProvider` and passes
that value into `SIStateAggregation.memories`. The Memory-derived aggregate
input is therefore certified by the real provider handoff proof: A-only Memory
is visible under A, absent under B, B-only Memory is visible under B, and A is
restored on return. Full SI aggregation remains deferred: unrelated aggregate
inputs and global `si_engine_workspace_v1` are outside FIX-004C1 and require
the follow-on workspace repair.

The final closure suite includes FIX-004B, FIX-004A, FIX-001/002/003, and
Root-05 regressions, plus targeted analysis and detached exact-index
validation.

## FIX-004C2 — SI workspace V2 account authority

### Defect, model, and authority

`SiWorkspaceStore` persisted a JSON object containing SI conversation and
response workspace state under the global secure-store key
`si_engine_workspace_v1`. Its payload has no owner marker, account scope,
session identity, or provenance. It is therefore ambiguous legacy data, not
evidence that the current authenticated user owns it.

The active authority is
`si_engine_workspace_v2.<AccountStorageScope.v2Namespace>`. The store receives
an explicit `AccountStorageScope`, permits direct persistence only in a safe
authenticated scope, and has no authenticated fallback to the V1 key, a prior
account, or a signed-out namespace. `si_engine_workspace_v1` is preserved,
inactive, unclaimed, unmigrated, and never deleted by C2.

### Provider graph and projection

`accountStorageScopeProvider` is watched by `siWorkspaceStoreProvider`.
`siEngineServiceProvider` watches that store, and `siEngineStateProvider`
watches both the scope and service. The service is used by `AIController`; the
SI Console screen model watches `siEngineStateProvider`. Existing Root-05
lifecycle invalidation already disposes `siEngineServiceProvider`,
`siEngineStateProvider`, `AIController`, and the SI Console model during an
account transition. No additional lifecycle hunk is required.

The public `siEngineStateProvider` returns `null` while signed out or unsafe,
so no prior authenticated workspace becomes the current signed-out projection.
Direct `SiWorkspaceStore` access remains fail-closed in those scopes.

`siStateAggregationProvider` does not consume SI workspace directly or through
`siEngineStateProvider`; its workspace-input certification is therefore N/A,
not a fabricated aggregate proof. SI Console's workspace data source is the
separate scoped `siEngineStateProvider` chain described above.

### Certification and remaining blockers

Focused coverage proves A→B→A isolation and rehydration, same-user rebuild,
signed-out→B isolation, rapid A→B→C isolation, V1 sentinel preservation, and
scoped read and write failure/retry without fallback. There is no workspace
delete/clear API, so delete/clear isolation is N/A.

FIX-004C1 Memory regression remains required. Full SI aggregation remains
deferred because it has unrelated uncertified inputs; C2 removes only the
global durable workspace blocker. Recovery, sync, reminders, bridge, and final
aggregate certification remain FIX-004C3 work.

## FIX-004C3 PRE-REPAIR-01A — Account-scoped notification ledger

### Authority and compatibility policy

`notification_entries_v1` was a global notification ledger and therefore could
expose a prior account's in-app notification title, body, source, or action
metadata. The active authority is now
`notification_entries_v2.<AccountStorageScope.v2Namespace>`. It is available
only to a safe authenticated scope. V1 is preserved byte-for-byte, inactive,
unclaimed, and has no fallback or migration path.

`notificationsRepositoryProvider` watches the storage scope and constructs the
repository with it. `domainNotificationRepositoryProvider` watches that
repository, so the notification domain boundary recreates with the active
account.

### Projection and command handoff

`NotificationNotifier` watches the scope and domain repository, begins each
new projection empty, and uses a generation plus current-scope check before an
asynchronous reload can write state. This rejects late A/B reads during rapid
transitions.

Certification also found a separate command-lifetime defect:
`scheduleNotificationUseCaseProvider` was cached after `ref.read` captured an
account-specific repository. A notification pushed after A→B could therefore
be written into A's ledger. `NotificationNotifier.push()` now schedules through
the current `domainNotificationRepositoryProvider`; command routing and the
projection now use the same current scoped authority.

### Certification

The exact-index candidate passed 86 tests: 8 focused notification tests and 78
cross-program regression tests. Coverage proves A→B→A provider/repository
isolation, identical-ID isolation, signed-out and signed-out→B behavior,
rapid and late-load race rejection, scoped read failure, write failure/retry,
cancel/disable isolation, and private `pushDecision` metadata isolation.
The real Goal reminder path persists its in-app ledger entry only in the
current V2 account namespace. Targeted analysis reported zero diagnostics.

Platform schedule ownership, platform reminder identifiers, outgoing-account
platform cancellation, and the Habit, Daily Planning, Reflection, and Profile
streak-break direct platform producer paths remain explicitly deferred to
PRE-REPAIR-01B. They are not certified or changed by 01A.

## FIX-004C3 PRE-REPAIR-01B — Account-owned platform reminders

PRE-REPAIR-01B establishes `reminder_schedule_registry_v2.<v2Namespace>` as
the durable ownership ledger for platform reminder IDs. The lifecycle
coordinator drains reminder work and cancels the outgoing scope's registry
before invalidating account-scoped providers and activating the incoming scope.
Cancellation errors retain registry evidence for a retry; successful
cancellation removes ownership only after the platform cancellation succeeds.

| Producer | Account-safe ID / authority | Result and ownership behavior |
| --- | --- | --- |
| Goal | `reminder.goal.<v2Namespace>.<goalId>` | Existing result-aware platform path registers only after scheduling. |
| Habit | `reminder.habit.<v2Namespace>.<habitId>` | Existing result-aware platform path is registered in the shared ledger. |
| Daily Planning | `reminder.daily_planning.<v2Namespace>` | Scoped preference and registry ownership are durable across recreation. |
| Reflection | `reminder.reflection.<v2Namespace>.default` | Preferences are `reflection_reminder_*_v2.<v2Namespace>`; global keys remain inactive and unclaimed. |
| Profile streak-break | `reminder.profile_streak.<v2Namespace>.<YYYY-MM-DD>` | Uses `scheduleWithResult`; ownership is recorded only after `scheduled`. |

`NotificationsRepository.scheduleNotification()` remains the compatibility,
best-effort path: it persists the scoped in-app ledger entry first and logs a
platform scheduling exception. Account-owned platform producers instead use
`NotificationsService.scheduleWithResult()`, which returns the existing
`NotificationScheduleResult` or propagates a platform exception. Thus a
failed platform schedule cannot create registry ownership; the scoped in-app
ledger entry remains consistent with the pre-existing notification-ledger
contract.

The producer suites certify same-logical-ID/date A/B collision isolation,
restart/recreation of registry ownership, cancellation failure retention and
retry, stale asynchronous registration rejection during rapid A→B→C, and
same-user deduplication. Outgoing platform cleanup does not erase scoped
Reflection preferences, reminder settings, Profile state, Goal/Habit state, or
notification ledger records. Signed-out scope cannot create authenticated
platform ownership or hydrate a prior account registry.

PRE-REPAIR-01B is a reminder-platform closure only. FIX-004C3 remains open for
the non-reminder recovery, sync, bridge, and aggregate runtime work.

## FIX-004C3 â€” Sync queue account ownership

### Evidence boundary

The canonical queue authority is `sync_queue_v2` in the account-scoped Hive
box `offline_queue_box.<AccountStorageScope.v2Namespace>`. The former global
`sync_queue_v1` key is preserved, inactive, unclaimed, and never used as a
fallback. Signed-out and unsafe scopes expose an unavailable queue.

| Invariant | Evidence level |
| --- | --- |
| A/B storage and same-ID isolation; ack/remove isolation; restart | Proven directly |
| Provider recreation, signed-out projection, dispatcher revocation, count, rapid transitions | Proven via real provider chain |
| Stale completion and retry remain account-local | Proven via real queue runner with deterministic transport |
| Flush transport receives only the current account operation | Proven via the real flush provider with an overrideable apply boundary |
| Outgoing dispatcher drain precedes invalidation; boundary ready precedes write resume | Structurally proven by the committed lifecycle contract tests |

Direct authenticated Aâ†’B is intentionally forbidden by the ownership-safety
policy in `AuthSessionLifecycleCoordinator._transitionSerial`; a required
signed-out/no-account boundary separates owners. This is not a sync defect.

### Shared lifecycle integration harness â€” deferred certification dependency

An end-to-end coordinator fixture is shared C3 infrastructure, not sync
ownership work. It needs compatible test doubles or overrides for auth,
ownership storage, cleanup, session recovery, reminders, sync actions,
repositories, bridge, profile, learning, bootstrap, and the invalidated
provider graph. It must drive the real coordinator, record the existing
`AuthSessionLifecycleObserver` events, and support the authoritative sequence
`A â†’ signed-out â†’ B`, restart, and safety-gate failures.

Later subsystem tests plug in controlled sync transport through
`supabaseSyncApplyProvider`, recovery/bridge/reminder fakes through their
existing providers, and SI/context providers through overrides. The harness
must not weaken lifecycle ordering or allow direct authenticated Aâ†’B merely
to simplify tests.

The remaining integration-only properties are the full coordinator's
no-mutation window, in-flight sync completion/failure across that coordinator
boundary, and account-local flush behavior while the full runtime graph is
active. All other listed sync ownership invariants are certified at their
actual storage, dispatcher, runner, or provider boundary.

## FIX-004C3 final runtime handoff certification

FIX-004C3 is complete. The active authorities are account-scoped V2 state for
the notification ledger, platform reminder registry, sync queue, Session
Recovery, SoulMap, Neural History, durable SI Memory/workspace, Settings/theme,
and ExtendedDomain data. Legacy V1/global records remain preserved, inactive,
unclaimed, and unavailable as fallback input.

The notification scheduler exposes a narrow injected cancel-all seam solely
for deterministic lifecycle testing; production continues to use the platform
scheduler. The real lifecycle cleanup wiring supplies that scheduler to the
existing cleanup boundary. Reminder ownership, cancellation semantics, and
notification identifiers are unchanged.

The Theme projection now watches the current `SettingsPreferenceController`
`AsyncValue` directly, awaiting its future only for initial loading. A theme
cannot remain projected from a previous scope after scoped Settings changes.

### Authoritative ownership policy

- A -> signed-out is allowed; A's durable V2 state remains parked.
- signed-out -> A is allowed; fresh A runtime state restores and writes resume.
- direct A -> B is rejected.
- signed-out -> B is rejected while the retained owner marker is A.
- Explicit export-and-clear remains future work and is out of scope.

The real coordinator records the safety order: `suspend_writes` ->
`cancel_and_drain` -> `invalidate` -> `identity_handoff` ->
`boundary_ready` -> `resume_writes` (only for a valid authenticated A
transition). Stale dispatcher objects are revoked, signed-out paths fail
closed, and restart retains the owner marker.

SI aggregation, Nexus, Smart Planner, Trajectory, and SI Console are certified
through their real provider/context chains. The shared lifecycle fixture is
certified. Final regression execution: **229/229/0**; targeted analyzer:
**0 diagnostics**.
