# Phase 4F.0 — Settings / Preferences Authority Isolation

## HLM-06 definition

| ID | Group | Severity | Problem | Required tests |
| --- | --- | --- | --- | --- |
| HLM-06 | D | P2 | Route preference ownership through a documented settings boundary. | Preference propagation tests |

The affected Human Life Model concepts are preferences, settings, and profile/theme/onboarding propagation. HLM-06 must not create a competing truth for HLM-01 intake, HLM-02 history, HLM-03 intervention outcomes, HLM-04 PlannerInput, or HLM-05 progression.

## Protected files and provenance

| File | HEAD blob | Current SHA-256 | Phase 2 snapshot | Current equals snapshot |
| --- | --- | --- | --- | --- |
| `lib/data/repositories/settings_repository.dart` | `3815dffe11e384302dd1e25ba58bf1c607143298` | `B8520F5F4BA71F6CC5B2C773BF134AE1A7B4D95DB0082712B312D9D87071DE4A` | unavailable in this environment | unverified |
| `lib/data/di/repositories_providers.dart` | `6383804724f7465be75bf58b6358b745aa67ca8e` | `E680DFEBD4EB379278702E5977F20FA72377053B65407A0481F1C482F25491C6` | unavailable in this environment | unverified |

Phase 2 records identify a protected local snapshot, but its recovery path is outside the permitted filesystem. No conclusion about snapshot equality is made here.

## Dirty-hunk inventory

| ID | Region | Classification | Effect | HLM-06 overlap |
| --- | --- | --- | --- | --- |
| SETTINGS-REPO-H01 | repository fields and `cancelAndDrain`/`dispose` | SYNC/CANCELLATION | introduces cancellation and queued writes | DIRECT |
| SETTINGS-REPO-H02 | `saveSettings` serialization wrapper | SHARED-BOUNDARY | serializes persistence and sync writes; rejects post-cancellation writes | DIRECT |
| REPO-PROVIDERS-H01 | task/goal/habit providers | PROVIDER-LIFECYCLE | watches dispatcher and disposes repositories | NONE |
| REPO-PROVIDERS-H02 | `settingsRepositoryProvider` | PROVIDER-LIFECYCLE | watches dispatcher and disposes settings repository | DIRECT |
| REPO-PROVIDERS-H03 | sync dispatcher provider | USER-SCOPING / PROVIDER-LIFECYCLE | passes authenticated user id and disposes dispatcher | DIRECT |

All hunk behavior is protected pending snapshot/provenance confirmation. It is not staged or normalized by this phase.

## Current authority trace

`SettingsEntity` carries `soundEnabled`, `notificationsEnabled`, `themeMode`, and `onboardingComplete`. `SettingsRepository` persists those fields as JSON under `settings_entity_v1` through `SharedPrefsStore`, then enqueues a `settings` sync upsert. It is the credible canonical persistence candidate, but it is not yet the authoritative preference boundary because active consumers also use independent providers and keys.

The protected repository changes establish ordered write/cancellation behavior. The DI changes bind repository and dispatcher lifecycle to provider disposal and pass the authenticated user id into sync dispatch. HLM-06 must preserve these semantics: cancellation prevents stale writes after account transitions; serialization keeps local and sync writes ordered; user-scoped dispatch prevents cross-account sync attribution.

## Preference-truth inventory and scope

| Concept | Current owner(s) | Persistence | Classification | HLM-06 treatment |
| --- | --- | --- | --- | --- |
| Theme | `CurrentThemeController`, theme repository, `SettingsEntity.themeMode` | theme store plus settings JSON | USER PREFERENCE / duplicate | IN; adapt theme to settings boundary later |
| Sound | `soundEnabledProvider`, `ProfileState`, `SettingsEntity` | runtime provider, profile JSON, settings JSON | USER PREFERENCE / duplicate | IN; preserve Profile compatibility adapter |
| Notifications | settings entity and reminder services | settings JSON and feature keys | USER PREFERENCE plus FEATURE STATE | IN for global consent; adapters/defer feature schedules |
| Onboarding completion/version/step | app providers, bootstrap, `PreferenceService`, auth-session lifecycle, settings entity | user-scoped and global SharedPreferences keys | ONBOARDING STATE | ADAPTER/DEFER; do not make workflow progress a settings preference |
| Reminder schedules | reminder services | feature-specific SharedPreferences keys | FEATURE STATE | DEFER, with propagation adapter only if required |
| Generic user-preferences JSON | `PreferenceService` | `user_preferences_json` | UNKNOWN | LEGACY-ADAPTER candidate |
| Last opened tab | `PreferenceService` | `last_opened_tab` | FEATURE STATE | DEFER |
| Accessibility/display and feature flags | feature providers/services | mixed local keys | USER PREFERENCE or FEATURE STATE | inventory before migration; DEFER |

At least eight independent preference/state truths are present. No profile progression, intake, history, planner input, or intervention state belongs to Settings.

## Entity and service assessments

`SettingsEntity` is **suitable with extension** for global user preferences: it has defaults, immutable copy behavior, and validation, but no explicit serialization/version type and wrongly conflates onboarding workflow completion with preference fields.

`PreferenceService` should become a **legacy compatibility/read facade**: onboarding keys remain onboarding state, last-tab remains feature state, and the generic JSON bag needs classification before any migration.

Theme is currently owned by the theme controller/repository; recommended owner is canonical settings preference state with theme repository as an adapter. Sound is currently duplicated across runtime provider, profile state, and settings; recommended owner is canonical settings preference state with Profile compatibility preserved. Onboarding is dedicated workflow state, not a user preference; the legacy `SettingsEntity.onboardingComplete` field requires adapter/deprecation treatment, not forced migration.

## Required HLM-06 regions and strategy

| Path/region | Overlap | Future role |
| --- | --- | --- |
| `SettingsEntity` | NONE | canonical preference aggregate refinement |
| `SettingsRepository` persistence/read/write | DIRECT | retain protected concurrency/scoping; adapt above or isolate hunk |
| `repositories_providers.dart` settings/dispatcher providers | DIRECT | preserve lifecycle and user-scoped dispatch |
| `PreferenceService` | NONE | legacy adapter classification |
| settings state/provider/controller | PARTIAL | canonical producer/read boundary |
| theme provider/repository | PARTIAL | adapter consumer |
| Profile sound path | DIRECT, protected Profile boundary | compatibility-only adapter |
| onboarding/bootstrap/auth lifecycle | DIRECT/UNKNOWN | explicitly deferred workflow ownership |
| reminder/feature services | PARTIAL | deferred feature-state adapters |

The safest strategy is **adapt above the protected baseline, with deterministic hunk isolation where repository/DI integration is unavoidable**. A preservation commit is **NEEDS USER DECISION**: snapshot provenance is not currently readable, and the DI file includes unrelated task/goal/habit lifecycle hunks. HLM-06 cannot currently proceed without preserving—not replacing—the protected behavior.

## Branch history and test matrix

History contains existing settings/sync-related work but no reviewed, attributable replacement for the protected current semantics. No branch is merged or cherry-picked.

Required future tests: entity serialization/defaults; repository round-trip; user-scope isolation and account switching; ordered/cancelled writes; theme and sound propagation; onboarding workflow ownership; reminder adapter behavior; `PreferenceService` legacy keys; unknown/legacy data; restart hydration; and settings UI → canonical state → consumer continuity.

## Status

This phase changes documentation only. HLM-06 remains **BLOCKED** until the protected snapshot can be verified or the user authorizes a clearly scoped preservation baseline decision.
