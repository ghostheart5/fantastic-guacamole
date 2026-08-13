# LIFE-ROOT-05A — Identity-owned work drain / invalidation boundary

## Result

The untracked authoritative lifecycle coordinator has **14** remaining
baseline diagnostics. It is a caller/coordinator, not a Root-05 commit source.
The repair is a **C — multi-file identity baseline**; its dirty sources must be
isolated before implementation because several overlap protected HLM-06 work.

## Diagnostics

| ID | Family | Lifecycle call | Missing from HEAD |
| --- | --- | --- | --- |
| IDENTITY-DRAIN-DEP-01…04 | drain | task/goal/habit/settings `cancelAndDrain()` | repositories |
| IDENTITY-DRAIN-DEP-05 | drain | `SyncMutationDispatcher.cancelAndDrain()` | dispatcher |
| IDENTITY-DRAIN-DEP-06 | drain | `SessionRecoveryService.cancelAndDrain()` | recovery |
| IDENTITY-DRAIN-DEP-07 | drain | `SyncActions.cancelAndDrain()` | sync facade |
| IDENTITY-DRAIN-DEP-08 | drain | `cancelAndDrainExtendedDomainSessionState(ref)` | provider helper |
| IDENTITY-DRAIN-DEP-09…10 | drain | Profile/Learning `cancelAndDrainWrites()` | controllers |
| IDENTITY-DRAIN-DEP-11 | drain | `ReminderOrchestratorService.cancelAndDrain()` | reminder owner |
| IDENTITY-DRAIN-DEP-12 | sync | `IdentityAccountController.synchronizeAuthenticatedUser(user)` | identity provider |
| IDENTITY-DRAIN-DEP-13…14 | invalidate | ExtendedDomain/Insights invalidators | provider helpers |

All are direct calls in `_cancelAndDrainIdentityOwnedWork` (lines 1372–1408)
or `_invalidateIdentityOwnedState` (lines 1457/1476) of the lifecycle source.
HEAD lacks these APIs; the current dirty sources expose them. `sync_provider`
already provides its drain API at HEAD and is required but no change.

## Ordering contract

For a transition, the coordinator: begins the boundary generation; suspends
bridge writes; awaits identity-owned drains (including bridge mutation drain);
checks the generation; invalidates in-memory identity-owned state; clears the
identity; performs sign-out/deletion cleanup; verifies ownership and optional
legacy migration; claims the next owner; sets the next identity; hydrates and
bootstraps it; completes the boundary; and only then resumes bridge writes for
an authenticated user. Monetization invalidation occurs with the post-drain
provider invalidation set. Failed transitions remain blocked rather than
reactivating stale work.

## Semantics and invariants

Each owner closes/observes its own admission gate, waits for accepted work to
settle or safely skip, and is repeat-safe. A drain is not deletion. Invalidation
only drops in-memory/provider state after draining; durable local data is
deleted solely by explicit cleanup/deletion flows. Synchronization maps the
current auth `User` to in-memory `ChronoSparkIdentity`, preserving optional
identity details only for the same account.

Required invariants: no A work after the transition gate; accepted A work does
not commit into B; B hydrates independently; drain precedes invalidation;
failed transitions may remain safely blocked/resumable; successful transitions
never resume stale A work; repeated operations are safe; and an individual
failed task cannot poison a later-user queue.

## Manifest and provenance

**Modify in Root-05 (13 tracked-dirty files):** task, goal, habit, settings,
sync dispatcher, session recovery, domain-usecase providers, Profile, Learning,
reminder orchestrator, identity-account provider, and insights provider; plus
the ExtendedDomain owner already protected by Root-03 work. **Required but no
change (1):** `state/providers/sync_provider.dart`. **Required untracked (1):**
`state/providers/auth_session_lifecycle_provider.dart` (SHA-256
`4597114C3BA01A4BDE4B60BEF37F0D1E7A232F85EE2A91E54CAD14E408806976`,
snapshot-verified per BASE-03; excluded from commits).

The tracked candidates are dirty, and Settings/Profile are also HLM-06
integration boundaries. Hunk counts range from 1 to 136; provenance is mixed
(snapshot-verified for previously isolated baseline candidates; changed since
snapshot for protected Profile/Settings boundaries). No Root-05 hunk is
selected yet: the exact dependency graph is clear, but per-file hunk isolation
is required first. History contains `6b5af534 fix(sync): restore lifecycle-safe
sync actions`, confirming the sync façade as a separate established owner.

## Eventual tests

No work; queued work waits; gate refusal; safe in-flight settlement; repeat
drain; failure isolation; A→B commit prevention; failed/successful transition
resume rules; active-user synchronization; drain-before-invalidate ordering;
non-destructive invalidation; A provider invalidation/B hydration; disposal;
and repeat transition safety.

## Next action

**NEEDS-SUBSYSTEM-ISOLATION — LIFE-ROOT-05B.** First isolate the selected drain,
sync, and invalidation hunks from the tracked-dirty owners. Do not implement,
stage, or commit the lifecycle source or HLM-06 in Root-05A.
