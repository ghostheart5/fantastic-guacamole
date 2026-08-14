# FIX-004B — Account-State Persistence Handoff

## FIX-004B1 — Profile

### Authority

Profile's authenticated runtime authority is
`profile_state_v3.<AccountStorageScope.v2Namespace>`. The namespace is the
canonical V2 base64url encoding (including any standard padding) supplied by
`AccountStorageScope`; the Profile
controller does not inspect auth state independently.

The controller reads and writes only that key while the scope is authenticated
and storage-ready. Unsafe, transitioning, blocked, and signed-out scopes do
not hydrate or persist Profile state. The authenticated backup provider uses
the same V2 key and disables its legacy Hive fallback.

### Legacy preservation

The following sources have no per-record ownership proof and are inactive:

- secure `profile_state_v2`;
- Hive `profile_box/profile_state`; and
- sanitized V1 `profile_state_v2.<legacy-user>`.

`ProfileController.migrateLegacyStorage` therefore returns
`preservedAmbiguous`: it does not copy, hydrate, delete, or mark any of these
sources as migrated. The signed-out lifecycle handoff no longer transfers the
legacy sanitized Profile record into an authenticated account.

### Auth and Settings seams

The AuthService's verified-user seed now targets the canonical Profile V2
authority. It is legitimate only because it is generated from the verified
current auth user. Settings' old Profile-sound compatibility reader has been
disabled: it returns no legacy value rather than reading a V1 sanitized Profile
record. Settings ownership migration remains FIX-004B3 work.

### Handoff and validation

Root-05 continues to drain Profile writes and invalidate `profileProvider`,
`profileValuesProvider`, and `progressionProvider` before the next storage
scope is made ready. Focused B1 coverage proves A/B isolation, restart,
signed-out-to-B isolation, ambiguous secure/V1 preservation, unsafe-scope
failure closure, and scoped read/write failure without a legacy fallback.

The exact-index candidate was validated in a detached worktree with a blank,
untracked `.env`: 44 focused Profile, lifecycle, A4 core-handoff, namespace,
Settings-compatibility, and AuthService-hydration tests passed; targeted
analysis reported zero diagnostics. The two subsequently added same-user and
transition-failure Profile proofs also passed against the clean committed tree.

Durable SI/memory and all non-Profile account-state families remain outside
this repair.

## FIX-004B2 — Learning

### Authority and legacy preservation

Learning's authenticated runtime authority is
`ai_learning_v2.<AccountStorageScope.v2Namespace>`. `learningProvider` watches
`accountStorageScopeProvider`; it does not select a local namespace from auth
directly. A safe authenticated scope reads, writes, and resets only that V2
key. Unsafe, transitioning, blocked, and signed-out scopes expose the default
Learning state and do not hydrate or persist a fallback.

The former global `ai_learning` record and V1 sanitized
`ai_learning.<legacy-user>` records have no per-record ownership proof. They
remain preserved, inactive, unclaimed, and unmigrated. The Learning migration
helper returns `preservedAmbiguous`; the trusted-legacy lifecycle path no
longer invokes it. No global or V1 record is copied, deleted, or marked
migrated by the active runtime.

### Handoff and validation

Root-05's existing ordering remains unchanged: it cancels and drains Learning
writes, invalidates `learningProvider` and `learningHistoryProvider`, changes
scope, and constructs a new Learning controller. Learning-derived consumers
watch the provider; the SI pipeline's direct Learning input is therefore
B-only after a completed handoff. Full mixed SI aggregation certification is
still deferred.

Focused B2 coverage proves A→B→A isolation with identical field identifiers,
restart, signed-out→B, same-user refresh, global/V1 preservation, V2-only
reset, scoped read/write/delete failures, transition hydration failure, and a
direct Learning read-consumer handoff. Profile B1 and A4 core-handoff
regressions remain part of B2's exact-index validation.

## FIX-004B3 — Settings

Settings' authenticated local authority is
`settings_entity_v2.<AccountStorageScope.v2Namespace>`. The repository is
constructed from `accountStorageScopeProvider`; unsafe and signed-out scopes
are unavailable and do not read or write Settings. The former global
`settings_entity_v1`, device-global theme record, and legacy Profile-sound
record remain inactive compatibility data: no account-owned Settings hydration,
copy, deletion, or migration derives from them.

`settingsPreferencesProvider` watches account scope and reconstructs with the
repository. Root-05 retains its existing drain order and now invalidates the
Settings preference and current-theme projections with the repository. Theme,
sound, notification, and onboarding fields are account-owned because they are
serialized in `SettingsEntity`; legacy global theme/sound values are ambiguous.

Remote sync remains intentionally separate: `SyncMutationDispatcher` queues
the raw authenticated user ID, while the V2 namespace is local-only. Focused
B3 coverage proves A→B→A, same-user, restart, signed-out→B, legacy
preservation, fail-closed read/write behavior, projection recreation, and
wrong-user payload prevention. Full SI aggregation remains deferred because it
does not currently consume Settings directly.
