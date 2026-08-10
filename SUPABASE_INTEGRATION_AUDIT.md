# SUPABASE INTEGRATION AUDIT
Date: 2026-07-31
Scope: lib/, supabase/, test/

> **2026-08-09 correction:** This audit predates the core-sync implementation.
> `tasks`, `goals`, `habits`, and `settings` now have migrations in
> `supabase/migrations/20260804130000_create_core_sync_tables_with_rls.sql`
> and client remote gateways under `lib/data/remote/`. The older entries below
> that call those four tables absent or disconnected are superseded. Their live
> deployment and authenticated round-trip behavior remain unverified.
Mode: Read-only audit (no code changes)

## 1) Audit Method + Evidence Boundaries
- I audited all Supabase touchpoints in [lib](lib), [supabase](supabase), and [test](test).
- I verified migration/schema presence from SQL files under [supabase/migrations](supabase/migrations).
- I verified runtime schema references from application code paths (client.from, client.rpc, storage access, auth flows).
- I cannot query your live Supabase database directly from this environment, so live existence is inferred from:
  - migration DDL,
  - runtime references,
  - health-check probes in [lib/state/providers/supabase_backend_provider.dart](lib/state/providers/supabase_backend_provider.dart#L52).

## 2) Supabase Integration Inventory (Required Fields)

| TABLE NAME | FILE PATH | METHOD | READ | INSERT | UPDATE | DELETE | STREAM | STATUS |
|---|---|---|---|---|---|---|---|---|
| user_daily_metrics | [lib/system/analytics/global_aggregation_service.dart](lib/system/analytics/global_aggregation_service.dart#L37) | from(_kTable).upsert | No | Yes (upsert) | Yes (upsert) | No | No | CONNECTED ✅ |
| user_daily_metrics | [lib/system/analytics/global_aggregation_service.dart](lib/system/analytics/global_aggregation_service.dart#L118) | from(_kTable).select.eq | Yes | No | No | No | No | CONNECTED ✅ |
| user_daily_metrics | [lib/state/providers/supabase_backend_provider.dart](lib/state/providers/supabase_backend_provider.dart#L105) | from('user_daily_metrics').select.limit | Yes | No | No | No | No | CONNECTED ✅ |
| user_daily_metrics | [lib/state/providers/supabase_backend_provider.dart](lib/state/providers/supabase_backend_provider.dart#L199) | from('user_daily_metrics').stream | Yes | No | No | No | Yes | CONNECTED ✅ |
| monetization_subscription_statuses | [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L36) | from(...).select.eq.maybeSingle | Yes | No | No | No | No | CONNECTED ✅ |
| monetization_wallets | [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L58) | from(...).select.eq.maybeSingle | Yes | No | No | No | No | CONNECTED ✅ |
| monetization_credit_transactions | [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L80) | from(...).select.eq.order.limit | Yes | No | No | No | No | CONNECTED ✅ |
| monetization_entitlement_events | [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L105) | from(...).select.eq.order.limit | Yes | No | No | No | No | CONNECTED ✅ |
| consume_monetization_credits (RPC) | [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L122) | rpc('consume_monetization_credits') | No | Server-side | Server-side | Server-side | No | CONNECTED ✅ |
| consume_monetization_credits (RPC) | [lib/features/monetization/data/repositories/ai_credit_repository.dart](lib/features/monetization/data/repositories/ai_credit_repository.dart#L188) | rpc('consume_monetization_credits') | No | Server-side | Server-side | Server-side | No | CONNECTED ✅ |
| monetization_credit_packages (fallback chain) | [lib/features/monetization/data/repositories/ai_credit_repository.dart](lib/features/monetization/data/repositories/ai_credit_repository.dart#L23) | from(table).select.eq.order | Yes | No | No | No | No | PARTIALLY CONNECTED ⚠️ |
| monetization_wallets / ai_credit_wallets fallback | [lib/features/monetization/data/repositories/ai_credit_repository.dart](lib/features/monetization/data/repositories/ai_credit_repository.dart#L31) | from(table).select.eq.maybeSingle | Yes | No | No | No | No | PARTIALLY CONNECTED ⚠️ |
| monetization_credit_transactions / ai_credit_transactions fallback | [lib/features/monetization/data/repositories/ai_credit_repository.dart](lib/features/monetization/data/repositories/ai_credit_repository.dart#L35) | from(table).select.eq.order.limit | Yes | No | No | No | No | PARTIALLY CONNECTED ⚠️ |
| monetization_purchases / ai_credit_purchases fallback | [lib/features/monetization/data/repositories/ai_credit_repository.dart](lib/features/monetization/data/repositories/ai_credit_repository.dart#L39) | from(table).select.eq.order.limit | Yes | No | No | No | No | PARTIALLY CONNECTED ⚠️ |
| monetization_subscription_plans / subscription_plans fallback | [lib/features/monetization/data/repositories/subscription_repository.dart](lib/features/monetization/data/repositories/subscription_repository.dart#L13) | from(table).select.eq.order | Yes | No | No | No | No | PARTIALLY CONNECTED ⚠️ |
| monetization_subscription_statuses / subscriptions fallback | [lib/features/monetization/data/repositories/subscription_repository.dart](lib/features/monetization/data/repositories/subscription_repository.dart#L17) | from(table).select.eq.maybeSingle | Yes | No | No | No | No | PARTIALLY CONNECTED ⚠️ |
| monetization_entitlement_events / entitlement_events fallback | [lib/features/monetization/data/repositories/entitlement_repository.dart](lib/features/monetization/data/repositories/entitlement_repository.dart#L14) | from(table).select.eq.order.limit | Yes | No | No | No | No | PARTIALLY CONNECTED ⚠️ |
| monetization_subscription_statuses / subscriptions fallback | [lib/features/monetization/data/repositories/entitlement_repository.dart](lib/features/monetization/data/repositories/entitlement_repository.dart#L18) | from(table).select.eq.maybeSingle | Yes | No | No | No | No | PARTIALLY CONNECTED ⚠️ |
| chronospark-sync bucket | [lib/data/services/sync_service.dart](lib/data/services/sync_service.dart#L105) | storage.from(bucket).download | Yes | No | No | No | No | CONNECTED ✅ |
| chronospark-sync bucket | [lib/data/services/sync_service.dart](lib/data/services/sync_service.dart#L155) | storage.from(bucket).uploadBinary | No | Yes | Yes (upsert) | No | No | CONNECTED ✅ |
| chronospark-sync bucket | [lib/state/providers/supabase_backend_provider.dart](lib/state/providers/supabase_backend_provider.dart#L117) | storage.from('chronospark-sync').list | Yes | No | No | No | No | CONNECTED ✅ |
| purchase_bindings (edge function REST) | [supabase/functions/monetization-verify/index.ts](supabase/functions/monetization-verify/index.ts#L99) | REST /rest/v1/purchase_bindings | Yes | Yes | No | No | No | CONNECTED ✅ |
| apply_verified_purchase (edge function RPC) | [supabase/functions/monetization-verify/index.ts](supabase/functions/monetization-verify/index.ts#L157) | REST /rest/v1/rpc/apply_verified_purchase | No | Server-side | Server-side | Server-side | No | CONNECTED ✅ |
| auth state | [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L53) | auth.onAuthStateChange | Yes | No | No | No | Stream | CONNECTED ✅ |

## 3) Migration Presence + Runtime Reference Verification

### Verified in migrations and used in runtime
- profiles
  - Migration: [supabase/migrations/202607110001_profiles.sql](supabase/migrations/202607110001_profiles.sql#L1)
  - Runtime: created by trigger handle_new_user on auth.users insert.
- user_daily_metrics
  - Migration: [supabase/migrations/202607110002_data_policies.sql](supabase/migrations/202607110002_data_policies.sql#L1), [supabase/migrations/20260717170000_secure_user_daily_metrics.sql](supabase/migrations/20260717170000_secure_user_daily_metrics.sql#L1)
  - Runtime: [lib/system/analytics/global_aggregation_service.dart](lib/system/analytics/global_aggregation_service.dart#L37), [lib/state/providers/supabase_backend_provider.dart](lib/state/providers/supabase_backend_provider.dart#L199)
- purchase_bindings
  - Migration: [supabase/migrations/202607050001_purchase_bindings.sql](supabase/migrations/202607050001_purchase_bindings.sql#L1)
  - Runtime: only edge function usage [supabase/functions/monetization-verify/index.ts](supabase/functions/monetization-verify/index.ts#L99)
- monetization_subscription_statuses
- monetization_wallets
- monetization_credit_transactions
- monetization_purchases
- monetization_entitlement_events
  - Migration: [supabase/migrations/20260716193000_monetization_system.sql](supabase/migrations/20260716193000_monetization_system.sql#L1)
  - Runtime: [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L36)

### Runtime references not backed by migrations in this repo
- monetization_credit_packages
- monetization_subscription_plans
- subscription_plans
- subscriptions
- entitlement_events
- ai_credit_wallets
- ai_credit_transactions
- ai_credit_purchases

Evidence: fallback table arrays in
- [lib/features/monetization/data/repositories/ai_credit_repository.dart](lib/features/monetization/data/repositories/ai_credit_repository.dart#L23)
- [lib/features/monetization/data/repositories/subscription_repository.dart](lib/features/monetization/data/repositories/subscription_repository.dart#L13)
- [lib/features/monetization/data/repositories/entitlement_repository.dart](lib/features/monetization/data/repositories/entitlement_repository.dart#L14)

Status: PARTIALLY CONNECTED ⚠️ due to schema ambiguity/fallback dependence.

## 4) Known Table Checklist (Requested)

| Table | In Migrations | Runtime Reference | Repo/Provider/UI wiring | Status |
|---|---|---|---|---|
| profiles | Yes | Trigger-based | No direct profile table repository/provider/UI reader from Supabase | PARTIALLY CONNECTED ⚠️ |
| tasks | No | No Supabase from('tasks') | Local Hive repository [lib/data/repositories/task_repository.dart](lib/data/repositories/task_repository.dart#L1) | BROKEN ❌ (for Supabase integration) |
| goals | No | No Supabase from('goals') | Local Hive repository [lib/data/repositories/goal_repository.dart](lib/data/repositories/goal_repository.dart#L1) | BROKEN ❌ |
| habits | No | No Supabase from('habits') | Local Hive repository [lib/data/repositories/habit_repository.dart](lib/data/repositories/habit_repository.dart#L1) | BROKEN ❌ |
| timeline_events | No | No Supabase from('timeline_events') | Local prefs repository [lib/data/repositories/timeline_repository.dart](lib/data/repositories/timeline_repository.dart#L1) | BROKEN ❌ |
| notifications | No | No Supabase from('notifications') | Local repository [lib/data/repositories/notifications_repository.dart](lib/data/repositories/notifications_repository.dart#L10) | BROKEN ❌ |
| settings | No | No Supabase from('settings') | Local repository [lib/data/repositories/settings_repository.dart](lib/data/repositories/settings_repository.dart#L8) | BROKEN ❌ |
| core_values | No | No direct Supabase table reference | App-state only | BROKEN ❌ |
| milestones | No | No direct Supabase table reference | App-state/local only | BROKEN ❌ |
| soul_maps | No | No direct Supabase table reference | App-state/local only | BROKEN ❌ |
| memoryEngine | No | No direct Supabase table reference | local engine memory layers | BROKEN ❌ |
| user_daily_metrics | Yes | Yes | provider + service + stream + health | CONNECTED ✅ |
| purchase_bindings | Yes | Yes (edge) | no client repository/provider/UI path | PARTIALLY CONNECTED ⚠️ |
| monetization_subscription_statuses | Yes | Yes | repo/provider/UI path | CONNECTED ✅ |
| monetization_wallets | Yes | Yes | repo/provider/UI path | CONNECTED ✅ |
| monetization_credit_transactions | Yes | Yes | repo/provider/UI path | CONNECTED ✅ |
| monetization_purchases | Yes | Yes | repo/provider/UI path | CONNECTED ✅ |
| monetization_entitlement_events | Yes | Yes | repo/provider/UI path | CONNECTED ✅ |

## 5) Storage Audit (chronospark-sync)

Bucket:
- Created in migration: [supabase/migrations/202607110002_data_policies.sql](supabase/migrations/202607110002_data_policies.sql#L69)
- RLS-like storage object policies (select/insert/update/delete scoped to auth.uid path prefix): same file lines 75-114.

Usage:
- Uploads: [lib/data/services/sync_service.dart](lib/data/services/sync_service.dart#L155)
- Downloads: [lib/data/services/sync_service.dart](lib/data/services/sync_service.dart#L105)
- Backups: full + tasks-only via object keys backup/full_backup.json and backup/tasks_backup.json.
- Restores: [lib/data/services/sync_service.dart](lib/data/services/sync_service.dart#L178)
- Missing bucket handling:
  - 404 download returns empty map gracefully.
  - Other storage errors logged and return false/empty.

Status: CONNECTED ✅

## 6) Auth Audit (Email/Password, Google, GitHub)

### Email/Password
- Sign in: [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L62)
- Sign up: [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L104)
- Session restore/refresh: [lib/features/auth/application/auth_controller.dart](lib/features/auth/application/auth_controller.dart#L34), [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L297)
- Sign out: [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L358)
- Token refresh/get token: [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L309)

Status: CONNECTED ✅

### Google Sign In
- OAuth flow: [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L148)
- UI trigger: [lib/features/auth/screens/auth_gate.dart](lib/features/auth/screens/auth_gate.dart#L485)

Status: CONNECTED ✅

### GitHub Sign In
- Usecase exists but explicitly unsupported: [lib/features/auth/domain/usecases/oauth/sign_in_with_github_usecase.dart](lib/features/auth/domain/usecases/oauth/sign_in_with_github_usecase.dart#L1)
- No runtime signInWithOAuth(OAuthProvider.github) path discovered.

Status: BROKEN ❌ (declared but not implemented)

### Profile generation
- DB trigger create/update profile from auth.users: [supabase/migrations/202607110001_profiles.sql](supabase/migrations/202607110001_profiles.sql#L60)
- Resilient wrapper trigger update: [supabase/migrations/20260712143000_resilient_handle_new_user.sql](supabase/migrations/20260712143000_resilient_handle_new_user.sql#L1)
- Local profile seed on signup also exists: [lib/data/services/auth_service.dart](lib/data/services/auth_service.dart#L128)

Status: PARTIALLY CONNECTED ⚠️ (db-triggered + local seed dual-path)

## 7) Write Path Quality (Success, Error, Logging, User Feedback)

### user_daily_metrics upsert
- Success path: await upsert
- Error path: catch and continue
- Logging: Yes (Logger.error)
- User feedback: No explicit UI feedback
- Evidence: [lib/system/analytics/global_aggregation_service.dart](lib/system/analytics/global_aggregation_service.dart#L37)
- Status: PARTIALLY CONNECTED ⚠️

### storage upload/download (backup)
- Success path: returns true/map
- Error path: retry + catch + fallback
- Logging: Yes
- User feedback: indirect (bool/empty result; no guaranteed UI toast)
- Evidence: [lib/data/services/sync_service.dart](lib/data/services/sync_service.dart#L89)
- Status: PARTIALLY CONNECTED ⚠️

### consume_monetization_credits RPC
- Success path: parse row -> wallet model
- Error path: throws MonetizationBackendException/FormatException
- Logging: not local in call site, but surfaced in controller state
- User feedback: Yes via controller error shown in UI
- Evidence: [lib/features/monetization/data/monetization_remote_data_source.dart](lib/features/monetization/data/monetization_remote_data_source.dart#L122), [lib/features/monetization/presentation/controllers/credit_store_controller.dart](lib/features/monetization/presentation/controllers/credit_store_controller.dart#L35), [lib/features/monetization/presentation/screens/credit_store_screen.dart](lib/features/monetization/presentation/screens/credit_store_screen.dart#L73)
- Status: CONNECTED ✅

### purchase verification edge flow
- Success path: structured PurchaseVerificationResult valid=true
- Error path: typed error codes (notConfigured/unauthenticated/network/http/invalid)
- Logging: handled in service result path (limited explicit logging)
- User feedback: controller surfaces result.message
- Evidence: [lib/features/monetization/data/services/purchase_verification_service.dart](lib/features/monetization/data/services/purchase_verification_service.dart#L74)
- Status: CONNECTED ✅

## 8) Model-to-Database Mapping Checks

### Strong matches found
- monetization_subscription_statuses -> SubscriptionStatus.fromMap
  - [lib/features/monetization/models/subscription_status.dart](lib/features/monetization/models/subscription_status.dart#L31)
  - schema fields present in [supabase/migrations/20260716193000_monetization_system.sql](supabase/migrations/20260716193000_monetization_system.sql#L1)
- monetization_wallets -> AiCreditWallet.fromMap/fromJson
  - [lib/features/monetization/models/ai_credit_wallet.dart](lib/features/monetization/models/ai_credit_wallet.dart#L34)
  - [lib/features/monetization/data/models/ai_credit_wallet.dart](lib/features/monetization/data/models/ai_credit_wallet.dart#L41)
- monetization_credit_transactions -> AiCreditTransaction.fromMap/fromJson
  - [lib/features/monetization/models/ai_credit_transaction.dart](lib/features/monetization/models/ai_credit_transaction.dart#L22)
  - [lib/features/monetization/data/models/ai_credit_transaction.dart](lib/features/monetization/data/models/ai_credit_transaction.dart#L42)
- monetization_purchases -> AiCreditPurchase.fromJson
  - [lib/features/monetization/data/models/ai_credit_purchase.dart](lib/features/monetization/data/models/ai_credit_purchase.dart#L58)
- monetization_entitlement_events -> EntitlementEvent.fromMap/fromJson
  - [lib/features/monetization/models/entitlement_event.dart](lib/features/monetization/models/entitlement_event.dart#L22)
  - [lib/features/monetization/data/models/entitlement_event.dart](lib/features/monetization/data/models/entitlement_event.dart#L22)

### Mismatch / nullability risks
- Dual model layers (features/monetization/models and features/monetization/data/models) increase drift risk.
- Fallback table aliases with differing schemas can silently degrade mapping assumptions.
- profiles table has no dedicated Supabase row model + direct read path in app.

Status: PARTIALLY CONNECTED ⚠️

## 9) Orphans, Unused, Missing Layers, Dead Code

### Orphan / underused DB objects
- purchase_bindings exists and is used by edge function only, not app repository/provider/UI directly.
  - [supabase/migrations/202607050001_purchase_bindings.sql](supabase/migrations/202607050001_purchase_bindings.sql#L1)
  - [supabase/functions/monetization-verify/index.ts](supabase/functions/monetization-verify/index.ts#L99)

### Missing repositories/providers/screens for requested core tables
- tasks/goals/habits/timeline_events/notifications/settings/core_values/milestones/soul_maps/memoryEngine do not have Supabase table integration in this repo.
- These features are predominantly local-storage driven.

### Dead/ambiguous integration candidates
- GitHub sign-in usecase is intentionally unsupported and never wired.
  - [lib/features/auth/domain/usecases/oauth/sign_in_with_github_usecase.dart](lib/features/auth/domain/usecases/oauth/sign_in_with_github_usecase.dart#L1)

## 10) Read-to-UI Verification

### Reads with clear UI consumption
- monetization_wallets -> credit balance widgets/screens
  - [lib/features/monetization/presentation/screens/credit_store_screen.dart](lib/features/monetization/presentation/screens/credit_store_screen.dart#L27)
  - [lib/features/monetization/presentation/screens/paywall_screen.dart](lib/features/monetization/presentation/screens/paywall_screen.dart#L35)
- monetization_credit_transactions + monetization_purchases -> history screen
  - [lib/features/monetization/presentation/screens/credit_history_screen.dart](lib/features/monetization/presentation/screens/credit_history_screen.dart#L10)
- monetization_subscription_statuses -> subscription management screen
  - [lib/features/monetization/presentation/screens/subscription_management_screen.dart](lib/features/monetization/presentation/screens/subscription_management_screen.dart#L10)

### Reads with non-direct UI display
- user_daily_metrics read/stream is used for health/integration snapshots and optimization logic, not full row-level dedicated UI.
  - [lib/state/providers/supabase_backend_provider.dart](lib/state/providers/supabase_backend_provider.dart#L199)
  - Integration text snapshot displayed in SI Console shell:
    [lib/features/si_console/ui/si_console_screen.dart](lib/features/si_console/ui/si_console_screen.dart#L1356)

Status: PARTIALLY CONNECTED ⚠️ for the strict requirement that every read is directly displayed.

## 11) User-Created Item Durability (Create/Read/Update/Delete + Restart + Login/Logout)

| Item | Create | Read | Update | Delete | Persist after restart | Persist after login/logout | Supabase-backed |
|---|---|---|---|---|---|---|---|
| Task | Yes | Yes | Yes | Yes | Yes (local Hive) | No (cleared on sign-out cleanup) | No |
| Goal | Yes | Yes | Yes | Yes | Yes (local Hive) | No (cleared on sign-out cleanup) | No |
| Habit | Yes | Yes | Yes (toggle) | Yes | Yes (local Hive) | No (cleared on sign-out cleanup) | No |
| Note | Yes (as task kind) | Yes | Yes | Yes | Yes (via task persistence) | No (cleared on sign-out cleanup) | No |
| Timeline Event | Yes | Yes | Partial (append/replace list) | Yes | Yes (local prefs) | No (cleared on sign-out cleanup) | No |
| Profile | Yes | Yes | Yes | Partial (reset/clear via cleanup) | Yes (secure/local) | No (cleared on sign-out cleanup) | Partially (DB trigger exists, app read path local-first) |

Evidence of logout cleanup clearing local domains:
- [lib/data/services/local_user_data_cleanup_service.dart](lib/data/services/local_user_data_cleanup_service.dart#L20)

Status against Supabase persistence expectation: BROKEN ❌ for core productivity objects.

## 12) Test Coverage for Supabase Paths

Covered:
- Auth service behavior with Supabase stubs
  - [test/features/auth/supabase_auth_service_test.dart](test/features/auth/supabase_auth_service_test.dart)
- Monetization connector/compat and provider tests
  - [test/features/monetization/unit/monetization_connector_actions_test.dart](test/features/monetization/unit/monetization_connector_actions_test.dart)
  - [test/features/monetization/unit/monetization_actions_compat_test.dart](test/features/monetization/unit/monetization_actions_compat_test.dart)
  - [test/providers/si_pipeline_provider_test.dart](test/providers/si_pipeline_provider_test.dart)

Gaps:
- No true live Supabase integration test in this repo run (networked test against deployed project).
- No direct test proving fallback table aliases exist in production schema.

Status: PARTIALLY CONNECTED ⚠️

## 13) Final Verdict

### CONNECTED ✅
- Supabase auth core (email/password, Google OAuth, session refresh, signout)
- Monetization core tables (subscription status, wallet, transactions, purchases, entitlement events)
- user_daily_metrics table write/read/stream
- chronospark-sync storage bucket (upload/download/list)
- Edge functions with JWT verification in [supabase/config.toml](supabase/config.toml)

### PARTIALLY CONNECTED ⚠️
- profiles (trigger-based creation is present, but no explicit app-side Supabase profile read/write repository path)
- purchase_bindings (edge-only usage)
- fallback alias tables that are referenced but not migrated in this repo
- strict write-path UX feedback consistency (some background failures are logged but not surfaced to user)
- strict every-read-visible-in-UI requirement

### BROKEN ❌
- GitHub sign-in flow (declared but not implemented)
- Requested core domain Supabase tables absent from schema/integration:
  tasks, goals, habits, timeline_events, notifications, settings, core_values, milestones, soul_maps, memoryEngine
- Core user-created productivity objects are not Supabase-persistent through login/logout lifecycle.

## 14) Highest-Priority Fix Order (Audit Recommendation Only)
1. Implement or remove GitHub auth path for consistency.
2. Decide and document target architecture for core productivity entities:
   local-only by design vs Supabase-backed multi-device sync.
3. If Supabase-backed is intended, add migrations + repositories + providers + UI bindings for tasks/goals/habits/timeline_events/notifications/settings/core_values/milestones/soul_maps/memoryEngine.
4. Replace fallback table ambiguity with a single canonical schema contract and migration coverage.
5. Add live integration tests for storage sync and monetization RPC/edge workflows.

---
Audit completed without code changes.
