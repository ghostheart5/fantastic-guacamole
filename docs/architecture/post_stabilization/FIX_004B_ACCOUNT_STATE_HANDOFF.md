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

## FIX-004B4 — ExtendedDomain V2

ExtendedDomain's authenticated authority is each base key suffixed with the
single canonical `AccountStorageScope.v2Namespace`: `<base>.v2.<base64url-id>`.
The service is constructed by `extendedDomainRepositoryProvider`, which watches
`accountStorageScopeProvider`; it never derives a namespace from auth directly.
Unsafe and signed-out scopes are unavailable: they neither hydrate nor retain
new in-memory writes.

The complete V2 key inventory is: `coach_messages`, `si_queries`,
`user_intents`, `journal_entries`, `analytics_metrics`, `app_notifications`,
`rewards`, `themes`, `settings`, `sync_states`, `offline_states`, `app_errors`,
`recovery_states`, `subscription_plans`, `privacy_policies`, and
`health_checks`, all under the `extended_domain.` prefix. Each has the same
read and write path through `ExtendedDomainService`; no authenticated active
path reads the corresponding global key.

Global and legacy V1 sanitized records have ambiguous ownership. The migration
helper is intentionally a no-op: it copies, deletes, marks, and claims none of
them. Runtime target and migration policy are consequently consistent—only a
V2 key is active and legacy records remain preserved/unclaimed.

Focused B4 tests exercise all sixteen families through A→B→A storage,
equivalent identifiers in both accounts, restart hydration, global/V1
preservation, signed-out/unsafe fail closure, and Root-05 drain durability.
The lifecycle continues to drain then invalidate the ExtendedDomain repository;
a later authenticated scope constructs a distinct scope-bound service. Direct
ExtendedDomain providers read that recreated repository. Durable SI memory and
platform-backed aggregation are not certified by B4.

### Provider handoff repair

The cached ExtendedDomain use-case providers now watch the scoped repository;
bootstrap and direct projections also track it. A focused ten-provider
handoff test proves A and B receive distinct repository and use-case instances.

### Harness-03A matrix

The real provider fixture exercises Coach, SI Query, Journal, Analytics, and
Extended Settings through A→B→A. All ten get/save use cases and the repository
recreate for B; B sees only B data and A restores only A data. Legacy sentinels
remain unchanged. Harness-02 remains green.

### Harness-02 storage-failure evidence

`test/helpers/controllable_shared_preferences_platform.dart` is a test-only
backend, enabled by direct dev dependency
`shared_preferences_platform_interface 2.4.2`. Tests restore the platform
instance and use public `SharedPreferences.resetStatic()` before and after each
case. It proves acquisition/hydration failure and B-scoped write failure plus
retry while preserving A and legacy sentinels. A post-initialization per-key
platform read failure is N/A: `getString` reads the initialized local cache.

### Final B4 projection and program certification

The B4 storage-authority repair was committed in `1e98ddee`; the scoped
repository and ten use-case lifetime repair was committed in `12d98b31`.
Final Harness-03B testing found one remaining projection boundary: the five
cached projections below had watched bootstrap completion but read their scoped
use case without establishing a dependency. On an account transition a
projection could therefore retain its prior synchronous snapshot. Each now
watches its corresponding scoped use-case provider:

- `coachMessagesProvider`;
- `siQueriesProvider`;
- `journalEntriesProvider`;
- `analyticsMetricsProvider`; and
- `appSettingsProvider`.

Harness-02 proves acquisition/hydration failure, retry, write failure/retry,
and preservation of A V2 and legacy data. Harness-03A proves the five-family
A-to-B-to-A matrix and all ten use-case provider recreations. Harness-03B
proves the direct `siQueriesProvider` path, same-user behavior, signed-out to
B isolation, and global/V1 SI-query preservation. SI Console has no separate
account-owned query cache: `si_console_screen.dart` reads `siQueriesProvider`,
which resolves through `getSiQueriesExtendedUseCaseProvider`,
`extendedDomainRepositoryProvider`, and the current scoped service.

The final regression replay also includes high-value B1 Profile, B2 Learning,
B3 Settings, A4 core handoff, FIX-001 lifecycle activation, FIX-002 readiness,
FIX-003 namespace, and Root-05 drain/lifecycle suites. Full mixed
`siStateAggregationProvider` certification remains deliberately deferred to
FIX-004C/platform-boundary work; it is not an ExtendedDomain B4 failure.

The exact-index candidate was rebuilt from `12d98b31` with only the bounded
projection repair, this record, the controllable-platform dev dependency, and
the certified B4 tests. Its complete closure replay passed **117/117** tests
with zero targeted analyzer diagnostics. The validation `.env` was blank,
untracked, unstaged, and uncommitted.

**Final decision: FIX-004B4 PASS.** All sixteen active families use their V2
authority, no active global ExtendedDomain route remains, repository/use-case
and projection handoff proofs pass, and legacy records remain unclaimed.
FIX-004B5 is ready; full Wave 1 remains blocked pending B5 and FIX-004C.

## FIX-004B5 — Four-family handoff certification

The final four-family boundary combines Profile (`profile_state_v3.<V2>`),
Learning (`ai_learning_v2.<V2>`), Settings (`settings_entity_v2.<V2>`), and
all sixteen ExtendedDomain V2 keys. No active account-state route uses a
global store; global and V1 data remains preserved and unclaimed.

The real-provider B5 fixture proves distinctive A values, explicit Root-05
equivalent invalidation, B isolation and B writes, A restoration, same-user
continuity, signed-out-to-B isolation, and an unsafe/superseded-C final scope.
It uses Profile and Learning controllers, Settings repository/preferences, and
the ExtendedDomain repository/use-case/projection chain. Settings and
ExtendedDomain repository instances recreate; Riverpod rebuilds the scoped
Profile/Learning notifier state on invalidation, so their B-only output rather
than notifier object identity is the valid proof. Legacy Profile, Learning,
Settings, and ExtendedDomain sentinels remain inactive.

The direct account-state input boundary is certified. Full
`siStateAggregationProvider` remains deferred to FIX-004C because durable
SI/memory and platform-backed dependencies are outside this four-family scope.

**Final decision: FIX-004B5 PASS; FIX-004B PASS.** Core planning/history and
account-state persistence are certified. Full Wave 1 remains blocked only on
FIX-004C, which is ready but intentionally not started here.

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
