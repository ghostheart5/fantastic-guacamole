# ChronoSpark Supabase Live Round-Trip Validation

Date: 2026-07-31
Scope: lib/, test/, supabase/
Mode: Audit + isolated validation utility/test only (no architecture rewrite, no repository deletion, no production behavior change)

## Deliverables Created
- [SUPABASE_ROUNDTRIP_VALIDATION.md](SUPABASE_ROUNDTRIP_VALIDATION.md)
- [lib/devtools/supabase_roundtrip_validator.dart](lib/devtools/supabase_roundtrip_validator.dart)
- [test/integration/supabase_roundtrip_validation_test.dart](test/integration/supabase_roundtrip_validation_test.dart)

## How Validation Works
The new validator in [lib/devtools/supabase_roundtrip_validator.dart](lib/devtools/supabase_roundtrip_validator.dart) performs runtime checks for:
- AUTH
- STORAGE
- USER DAILY METRICS
- MONETIZATION
- CORE PRODUCTIVITY ENTITY connectivity classification (structural audit mapping)

The optional integration test in [test/integration/supabase_roundtrip_validation_test.dart](test/integration/supabase_roundtrip_validation_test.dart) is opt-in and live-only. It runs only when all defines are present and `CHRONOSPARK_RUN_SUPABASE_LIVE_VALIDATION=true`.

## AUTH Round-Trip Readiness
Required checks and current status:
- current user exists: Implemented in validator, runtime-dependent
- session exists: Implemented in validator, runtime-dependent
- JWT/token available: Implemented in validator, runtime-dependent
- profile row exists in `profiles`: Implemented in validator (direct query)
- profile id matches `auth.uid`: Implemented in validator (strict equality)

Evidence:
- Auth sign-in/sign-up/session/token paths in [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L75), [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L104), [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L151), [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L317), [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L336)
- Profiles schema + policies in [supabase/migrations/202607110001_profiles.sql](supabase/migrations/202607110001_profiles.sql#L1)

## STORAGE Round-Trip Readiness
Required checks and current status:
- upload test object under `{uid}/validation/`: Implemented in validator
- download same object: Implemented in validator
- verify content match: Implemented in validator
- delete object if policy exists: Implemented in validator (warning if denied)

Evidence:
- App upload/download in [lib/data/services/sync_service.dart](lib/data/services/sync_service.dart#L105), [lib/data/services/sync_service.dart](lib/data/services/sync_service.dart#L155)
- Bucket health list probe in [lib/state/providers/supabase_backend_provider.dart](lib/state/providers/supabase_backend_provider.dart#L117)
- Bucket + object policies in [supabase/migrations/202607110002_data_policies.sql](supabase/migrations/202607110002_data_policies.sql#L69)

## USER DAILY METRICS Round-Trip Readiness
Required checks and current status:
- upsert validation row for date/device: Implemented in validator
- read row back and compare fields: Implemented in validator
- stream creation without crash: Implemented in validator

Evidence:
- Upsert/read in [lib/system/analytics/global_aggregation_service.dart](lib/system/analytics/global_aggregation_service.dart#L37), [lib/system/analytics/global_aggregation_service.dart](lib/system/analytics/global_aggregation_service.dart#L119)
- Health/stream in [lib/state/providers/supabase_backend_provider.dart](lib/state/providers/supabase_backend_provider.dart#L105), [lib/state/providers/supabase_backend_provider.dart](lib/state/providers/supabase_backend_provider.dart#L200)
- Table schema/policies in [supabase/migrations/202607110002_data_policies.sql](supabase/migrations/202607110002_data_policies.sql#L1)

## MONETIZATION Round-Trip Readiness
Required checks and current status:
- read `monetization_subscription_statuses`: Implemented in validator
- read `monetization_wallets`: Implemented in validator
- read `monetization_credit_transactions`: Implemented in validator
- read `monetization_entitlement_events`: Implemented in validator
- no credit consume during validation: enforced (read-only)
- missing wallet/status reported as initialization issue: enforced in validator messaging

Evidence:
- Runtime reads in [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L36), [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L58), [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L80), [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L105)
- Consume RPC exists but not called by validator in [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L127)
- Table DDL and RLS in [supabase/migrations/20260716193000_monetization_system.sql](supabase/migrations/20260716193000_monetization_system.sql#L1)

## CORE PRODUCTIVITY ENTITIES Connectivity Matrix

| Feature | Table | Local repository file | Supabase repository file | Provider file | UI screen if any | Create path | Read path | Update path | Delete path | Restart persistence | Login/logout persistence | Supabase persistence status | Classification | Evidence file paths and lines |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Tasks | tasks | [lib/data/repositories/task_repository.dart](lib/data/repositories/task_repository.dart#L13) | None | [lib/state/providers/task_provider.dart](lib/state/providers/task_provider.dart#L44) | [lib/features/creator/ui/widgets/creator_entry_lists.dart](lib/features/creator/ui/widgets/creator_entry_lists.dart#L12) | Yes (local) | Yes (local) | Yes (local) | Yes (local) | Yes (Hive) | Cleared on logout | Local persistence only | LOCAL ONLY ⚠️ | [lib/data/repositories/task_repository.dart](lib/data/repositories/task_repository.dart#L23), [lib/data/repositories/task_repository.dart](lib/data/repositories/task_repository.dart#L49), [lib/data/repositories/task_repository.dart](lib/data/repositories/task_repository.dart#L61), [lib/data/repositories/task_repository.dart](lib/data/repositories/task_repository.dart#L70) |
| Goals | goals | [lib/data/repositories/goal_repository.dart](lib/data/repositories/goal_repository.dart#L8) | None | [lib/state/providers/goals_provider.dart](lib/state/providers/goals_provider.dart#L21) | [lib/features/timeline/ui/timeline_screen.dart](lib/features/timeline/ui/timeline_screen.dart#L114) | Yes (local) | Yes (local) | Yes (local) | Yes (local) | Yes (Hive) | Cleared on logout | Local persistence only | LOCAL ONLY ⚠️ | [lib/data/repositories/goal_repository.dart](lib/data/repositories/goal_repository.dart#L18), [lib/data/repositories/goal_repository.dart](lib/data/repositories/goal_repository.dart#L44), [lib/data/repositories/goal_repository.dart](lib/data/repositories/goal_repository.dart#L61), [lib/data/repositories/goal_repository.dart](lib/data/repositories/goal_repository.dart#L70) |
| Habits | habits | [lib/data/repositories/habit_repository.dart](lib/data/repositories/habit_repository.dart#L33) | None | [lib/state/providers/habits_provider.dart](lib/state/providers/habits_provider.dart#L9) | [lib/state/providers/momentum_engine_provider.dart](lib/state/providers/momentum_engine_provider.dart#L40) | Yes (local) | Yes (local) | Yes (toggle) | Yes (local) | Yes (Hive) | Cleared on logout | Local persistence only | LOCAL ONLY ⚠️ | [lib/data/repositories/habit_repository.dart](lib/data/repositories/habit_repository.dart#L40), [lib/data/repositories/habit_repository.dart](lib/data/repositories/habit_repository.dart#L63) |
| Timeline Events | timeline_events | [lib/data/repositories/timeline_repository.dart](lib/data/repositories/timeline_repository.dart#L7) | None | [lib/state/providers/timeline_provider.dart](lib/state/providers/timeline_provider.dart#L29) | [lib/features/timeline/ui/timeline_screen.dart](lib/features/timeline/ui/timeline_screen.dart#L62) | Yes (local) | Yes (local) | Partial (save list) | Yes (local) | Yes (SharedPrefs) | Cleared on logout | Local persistence only | LOCAL ONLY ⚠️ | [lib/data/repositories/timeline_repository.dart](lib/data/repositories/timeline_repository.dart#L15), [lib/data/repositories/timeline_repository.dart](lib/data/repositories/timeline_repository.dart#L32), [lib/data/repositories/timeline_repository.dart](lib/data/repositories/timeline_repository.dart#L41), [lib/data/repositories/timeline_repository.dart](lib/data/repositories/timeline_repository.dart#L49) |
| Notifications | notifications | [lib/data/repositories/notifications_repository.dart](lib/data/repositories/notifications_repository.dart#L10) | None | [lib/state/providers/notification_provider.dart](lib/state/providers/notification_provider.dart#L12) | [lib/features/notifications/ui/notification_screen.dart](lib/features/notifications/ui/notification_screen.dart#L17) | Yes (local + scheduler) | Yes (local) | Yes | Yes | Yes (SecureStore) | Cleared on logout | Local persistence only | LOCAL ONLY ⚠️ | [lib/data/repositories/notifications_repository.dart](lib/data/repositories/notifications_repository.dart#L29), [lib/data/repositories/notifications_repository.dart](lib/data/repositories/notifications_repository.dart#L77), [lib/data/repositories/notifications_repository.dart](lib/data/repositories/notifications_repository.dart#L126), [lib/data/repositories/notifications_repository.dart](lib/data/repositories/notifications_repository.dart#L145) |
| Settings | settings | [lib/data/repositories/settings_repository.dart](lib/data/repositories/settings_repository.dart#L8) | None | [lib/state/providers/settings_ui_provider.dart](lib/state/providers/settings_ui_provider.dart#L113) | [lib/features/settings/ui/settings_screen.dart](lib/features/settings/ui/settings_screen.dart#L30) | Yes (local save) | Yes (local read) | Yes (local overwrite) | No explicit delete | Yes (SharedPrefs) | Cleared on logout | Local persistence only | LOCAL ONLY ⚠️ | [lib/data/repositories/settings_repository.dart](lib/data/repositories/settings_repository.dart#L15), [lib/data/repositories/settings_repository.dart](lib/data/repositories/settings_repository.dart#L42) |
| Core Values | core_values | None | None | [lib/state/providers/core_values_provider.dart](lib/state/providers/core_values_provider.dart#L13) | [lib/features/si_console/ui/si_console_screen.dart](lib/features/si_console/ui/si_console_screen.dart#L450) | No persisted create | Derived read only | No persisted update | No delete path | Derived/recomputed | Derived/recomputed | Table exists nowhere in app runtime | NOT IMPLEMENTED ❌ | [lib/state/providers/core_values_provider.dart](lib/state/providers/core_values_provider.dart#L13) |
| Milestones | milestones | Secure/local state | None | [lib/state/providers/milestones_provider.dart](lib/state/providers/milestones_provider.dart#L70) | [lib/features/progression/ui/progression_screen.dart](lib/features/progression/ui/progression_screen.dart#L109) | Yes (local) | Yes (local) | Yes (local) | Yes (local) | Yes (SecureStore) | Cleared on logout | Local persistence only | LOCAL ONLY ⚠️ | [lib/data/services/local_user_data_cleanup_service.dart](lib/data/services/local_user_data_cleanup_service.dart#L40) |
| Soul Maps | soul_maps | SharedPrefs key | None | [lib/state/providers/soul_map_provider.dart](lib/state/providers/soul_map_provider.dart#L45) | [lib/features/si_console/ui/si_console_screen.dart](lib/features/si_console/ui/si_console_screen.dart#L297) | Yes (local save) | Yes (local load) | Yes (set profile) | No explicit delete | Yes (SharedPrefs) | Not in logout clear list | Local persistence only | LOCAL ONLY ⚠️ | [lib/state/providers/soul_map_provider.dart](lib/state/providers/soul_map_provider.dart#L20), [lib/state/providers/soul_map_provider.dart](lib/state/providers/soul_map_provider.dart#L35) |
| Memory Engine | memoryEngine | [lib/data/repositories/memory_repository.dart](lib/data/repositories/memory_repository.dart#L8) | None | [lib/state/providers/memories_provider.dart](lib/state/providers/memories_provider.dart#L33) | [lib/features/si_console/ui/si_console_screen.dart](lib/features/si_console/ui/si_console_screen.dart#L3) | Yes (local) | Yes (local) | Yes (save existing id) | Yes (local) | Yes (SharedPrefs) | Cleared on logout | Local persistence only | LOCAL ONLY ⚠️ | [lib/data/repositories/memory_repository.dart](lib/data/repositories/memory_repository.dart#L15), [lib/data/repositories/memory_repository.dart](lib/data/repositories/memory_repository.dart#L58), [lib/data/repositories/memory_repository.dart](lib/data/repositories/memory_repository.dart#L72), [lib/data/repositories/memory_repository.dart](lib/data/repositories/memory_repository.dart#L81) |

### Direct Supabase repository/table probes for core entities
No runtime `client.from(<core table>)` paths were found for tasks/goals/habits/timeline_events/notifications/settings/core_values/milestones/soul_maps/memoryEngine.

Evidence of no matches in lib scan:
- Regex scan for `from('tasks'|'goals'|'habits'|'timeline_events'|'notifications'|'settings'|'core_values'|'milestones'|'soul_maps'|'memoryEngine')` returned empty.

## Migration Reality vs Runtime Reality
- Present in Supabase migrations and runtime-connected:
  - `profiles`, `user_daily_metrics`, `monetization_subscription_statuses`, `monetization_wallets`, `monetization_credit_transactions`, `monetization_purchases`, `monetization_entitlement_events`, storage bucket `chronospark-sync`
- Not present as core productivity tables in migrations/runtime:
  - `tasks`, `goals`, `habits`, `timeline_events`, `notifications`, `settings`, `core_values`, `milestones`, `soul_maps`, `memoryEngine`

Evidence:
- [supabase/migrations/202607110001_profiles.sql](supabase/migrations/202607110001_profiles.sql)
- [supabase/migrations/202607110002_data_policies.sql](supabase/migrations/202607110002_data_policies.sql)
- [supabase/migrations/20260716193000_monetization_system.sql](supabase/migrations/20260716193000_monetization_system.sql)

## GitHub Sign-In Exposure Risk Rule
- `SignInWithGithubUsecase` is explicitly unsupported in [lib/features/auth/domain/usecases/oauth/sign_in_with_github_usecase.dart](lib/features/auth/domain/usecases/oauth/sign_in_with_github_usecase.dart#L5).
- Login UI exposes Google sign-in hooks, not GitHub button wiring, in [lib/features/auth/screens/auth_gate.dart](lib/features/auth/screens/auth_gate.dart#L485), [lib/features/auth/screens/auth_gate.dart](lib/features/auth/screens/auth_gate.dart#L578).

Conclusion: GitHub sign-in risk is not elevated to HIGH by the requested rule, because GitHub login is not actively exposed in the UI path audited here.

## RELEASE RISK

### BLOCKER
- Auth profile mismatch if validator reports `profiles.id != auth.uid` or profile row missing for authenticated user.
- Monetization bootstrap blocker if wallet/status cannot initialize for active user in production session (even when tables exist).

### HIGH
- Local-only tasks/goals/habits relative to cloud-sync expectations.
- Storage sync if upload/download check fails in live validator run.
- Core productivity lifecycle durability across login/logout is local-only and cleared via [lib/data/services/local_user_data_cleanup_service.dart](lib/data/services/local_user_data_cleanup_service.dart#L60).

### MEDIUM
- Missing Supabase CRUD paths for notifications/settings/milestones/soul maps/memory engine where product messaging implies cloud continuity.

### LOW
- GitHub sign-in unsupported but not currently surfaced as active login option in audited UI path.

## What Is Actually Working vs Pretending To Be Connected

Actually working (implemented Supabase round-trip capabilities):
- Auth core session/token flow
- Storage bucket upload/download path
- `user_daily_metrics` write/read/stream path
- Monetization read-path tables and RPC ecosystem (outside validator write operations)

Pretending/partial (looks cloud-capable but remains local or incomplete):
- Core productivity entities (tasks, goals, habits, timeline, notifications, settings, milestones, soul maps, memory engine) are local-first and mostly local-only for persistence
- No direct Supabase CRUD repositories for those entities
- Login/logout lifecycle currently clears large portions of local state, so no cloud rehydration exists for those entities

## Notes
- This report does not fake live pass results.
- The validator and optional integration test are now present to run real environment-backed verification.
- No production architecture or behavior was changed beyond isolated dev/test validation utilities.
