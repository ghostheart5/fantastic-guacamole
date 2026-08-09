# ChronoSpark Backend Staging Inventory

Scope: local tracked files only. No Supabase project, database, migration, or Edge Function deployment was contacted or changed. This report describes the final state implied by migration order; it does not prove any remote project matches it.

## 1. Migration Manifest

| File | Obvious purpose | Areas |
| --- | --- | --- |
| `202607050001_purchase_bindings.sql` | Bind purchase-token hashes to users | RLS/security, monetization |
| `202607110001_profiles.sql` | Profiles table and auth signup trigger | auth/profile, RLS/security |
| `202607110002_data_policies.sql` | Daily metrics and private sync storage policies | RLS/security, metrics, storage |
| `20260711160649_new-migration.sql` | Empty file | none apparent |
| `20260712143000_resilient_handle_new_user.sql` | Historical resilient profile trigger | auth/profile |
| `20260716193000_monetization_system.sql` | Monetization tables, grants, and RPCs | monetization/credits/subscriptions, RLS/security |
| `20260717170000_secure_user_daily_metrics.sql` | Repair daily metrics ownership and metrics function | metrics, RLS/security |
| `20260802120000_harden_security_definer_functions.sql` | Historical SECURITY DEFINER hardening | auth/profile, metrics, RLS/security |
| `20260804120000_harden_monetization_credit_rpc.sql` | Harden credit consumption and helper grants | monetization/credits/subscriptions, RLS/security |
| `20260804130000_create_core_sync_tables_with_rls.sql` | Create core sync tables with own-row policies | core sync tables, RLS/security |
| `20260804140000_harden_metrics_and_profile_provisioning.sql` | Profile repair and global metrics lockdown | auth/profile, metrics, RLS/security |
| `20260804150000_harden_ai_proxy_rate_limit.sql` | Persistent AI proxy rate limit | rate limiting, RLS/security |

## 2. Tables Found

All expected tables are present in tracked migrations. Remote/staging existence is **UNKNOWN**.

| Table | Columns / constraints | Keys and indexes | Ownership / RLS / grants |
| --- | --- | --- | --- |
| `public.profiles` | `id uuid`, `email text`, `full_name text`, `avatar_url text`, timestamps | PK `id`; FK `id -> auth.users(id)` cascade | `id`; RLS enabled; authenticated: SELECT/INSERT/UPDATE; own-row policies |
| `public.purchase_bindings` | `token_hash text`, `user_id uuid`, `product_id text`, `created_at timestamptz` | PK `token_hash`; FK `user_id -> auth.users` cascade | `user_id`; RLS enabled; authenticated CRUD; own-row policies |
| `public.user_daily_metrics` | `device_id text`, `date date`, `user_id uuid`, counters, `momentum_peak double precision`, timestamps | Final PK `(user_id,date)`; FK `user_id -> auth.users`; index `(device_id,date)` | `user_id`; RLS enabled; authenticated SELECT/INSERT/UPDATE; final SELECT/UPDATE own-row policies. No DELETE grant/policy found. |
| `public.tasks` | `user_id uuid`, `id text`, title/description/kind, priority/difficulty/energy, schedule/goal/subtasks/recurrence, completion/cancellation/due/duration, timestamps/deleted marker | PK `(user_id,id)`; FK `user_id -> auth.users`; index `(user_id,updated_at)`; checks: nonblank id/title, numeric ranges, JSON array, recurrence values, nonnegative duration | `user_id`; RLS enabled; authenticated CRUD; four own-row policies |
| `public.goals` | `user_id uuid`, `id text`, title/description/target/color/status, completion/archive/timestamps/deleted marker | PK `(user_id,id)`; FK; index `(user_id,updated_at)`; checks: nonblank id/title, ARGB range, status values | `user_id`; RLS enabled; authenticated CRUD; four own-row policies |
| `public.habits` | `user_id uuid`, `id text`, title/description/cadence/count/status/active, timestamps/deleted marker | PK `(user_id,id)`; FK; index `(user_id,updated_at)`; checks: nonblank id/title, cadence/status values, count `1..365` | `user_id`; RLS enabled; authenticated CRUD; four own-row policies |
| `public.settings` | `user_id uuid`, `id text`, booleans, `theme_mode text`, timestamps/deleted marker | PK `(user_id,id)`; FK; index `(user_id,updated_at)`; checks: `id='default'`, theme values | `user_id`; RLS enabled; authenticated CRUD; four own-row policies |
| `public.ai_proxy_rate_limits` | `user_id uuid`, `window_started_at timestamptz`, `request_count integer`, `updated_at timestamptz` | PK `user_id`; FK; check `request_count >= 0` | `user_id`; RLS enabled; all anon/authenticated table grants revoked; no table policy found; access is via RPC |
| `public.monetization_subscription_statuses` | user, plan/product/status, active/source/renewal, credits, dates, order/token hash/metadata | PK/FK `user_id` | `user_id`; RLS enabled; authenticated SELECT; own-row SELECT policy |
| `public.monetization_wallets` | user, balances/allowance/bonus/period/lifetime/tier/end/timestamp | PK/FK `user_id`; nonnegative balance checks | `user_id`; RLS enabled; authenticated SELECT; own-row SELECT policy |
| `public.monetization_credit_transactions` | uuid id, user, type/amount/balance/source/description/metadata/date | PK `id`; FK user; index `(user_id, created_at DESC)` | `user_id`; RLS enabled; authenticated SELECT; own-row SELECT policy |
| `public.monetization_purchases` | uuid id, user, product/type/platform/state/token/order/credits/plan/payload/dates | PK `id`; FK user; unique `(user_id,purchase_token_hash)`; index `(user_id, created_at DESC)` | `user_id`; RLS enabled; authenticated SELECT; own-row SELECT policy |
| `public.monetization_entitlement_events` | uuid id, user, event/plan/product/active/dates/metadata | PK `id`; FK user; index `(user_id, created_at DESC)` | `user_id`; RLS enabled; authenticated SELECT; own-row SELECT policy |

### Missing Expected Tables

None among the requested object names. `storage.buckets` is not created as an application table; migration `202607110002_data_policies.sql` upserts the private `chronospark-sync` bucket and creates policies on `storage.objects`.

## 3. Policies Found

All listed policies are `TO authenticated`.

| Table | Policy / command | USING | WITH CHECK | Ownership |
| --- | --- | --- | --- | --- |
| `profiles` | select own / SELECT | `auth.uid() = id` | - | yes |
| `profiles` | insert own / INSERT | - | `auth.uid() = id` | yes |
| `profiles` | update own / UPDATE | `auth.uid() = id` | `auth.uid() = id` | yes |
| `purchase_bindings` | select, insert, update, delete own | select/update/delete: `auth.uid() = user_id` | insert/update: `auth.uid() = user_id` | yes |
| `user_daily_metrics` | final select own / SELECT | `auth.uid() = user_id` | - | yes |
| `user_daily_metrics` | insert own / INSERT | - | `auth.uid() = user_id` | yes |
| `user_daily_metrics` | final update own / UPDATE | `auth.uid() = user_id` | `auth.uid() = user_id` | yes |
| `tasks`, `goals`, `habits`, `settings` | select / insert / update / delete own | select/update/delete: `(select auth.uid()) = user_id` | insert/update: `(select auth.uid()) = user_id` | yes |
| Monetization status, wallet, transactions, purchases, entitlement events | select own / SELECT | `(select auth.uid()) = user_id` | - | yes |
| `storage.objects` (`chronospark-sync`) | select / insert / update / delete own | bucket is `chronospark-sync` and first name segment equals `auth.uid()` | insert/update same predicate | yes, path prefix |

No policy is defined for `public.ai_proxy_rate_limits`; this is consistent with the final migration revoking direct table access from anon and authenticated roles.

Historical note: the broad `user_daily_metrics_select_authenticated USING (true)` policy is dropped by `20260717170000_secure_user_daily_metrics.sql`; the final tracked policy is `user_daily_metrics_select_own`.

## 4. Function / RPC Security Inventory

| Function | Final security / path | Final execute access | `auth.uid()` / target behavior | Amount validation / qualified references |
| --- | --- | --- | --- | --- |
| `handle_new_user()` | DEFINER; `public, pg_temp` | PostgreSQL, service role, and `supabase_auth_admin` only; trigger context only | No caller uid; rejects non-`auth.users` trigger context | n/a; `public.profiles` qualified |
| `ensure_profile_for_current_user()` | DEFINER; `public, pg_temp` | authenticated only; PUBLIC/anon revoked | requires `auth.uid()` and only creates/selects that ID | n/a; `auth.users` and `public.profiles` qualified |
| `set_user_daily_metrics_updated_at()` | default INVOKER; no path setting | no direct grant found; trigger function | applies `auth.uid()` only when `NEW.user_id` is null | n/a; table refs not applicable |
| `get_global_metrics()` | DEFINER; `public, pg_temp` | PUBLIC/anon/authenticated revoked | latest body does not check uid; inaccessible to normal authenticated users by grant | n/a; `public.user_daily_metrics` qualified |
| `ensure_monetization_wallet(uuid default null)` | INVOKER; historical `search_path=public` | final service-role only | historical body accepts arbitrary `target_user_id`; no equality check | n/a; qualified tables/functions |
| `reset_monetization_allowance(uuid default null)` | INVOKER; historical `search_path=public` | final service-role only | historical body accepts arbitrary target; no equality check | n/a; qualified tables/functions |
| `grant_monetization_credits(...)` | INVOKER; `public, pg_temp` | final service-role only | target not constrained; expected server-only | rejects null/zero/negative and amounts over 5000; qualified refs |
| `consume_monetization_credits(integer,text,jsonb)` | DEFINER; `public, pg_temp` | authenticated only; PUBLIC/anon revoked | requires `auth.uid()` and has no target parameter | rejects null/zero/negative and amounts over 1000; qualified refs |
| `apply_verified_purchase(...)` | INVOKER; historical `search_path=public` | service-role only | target not constrained; expected server-only | no generic amount input; qualified refs |
| `consume_ai_proxy_rate_limit()` | DEFINER; `public, pg_temp` | authenticated only; PUBLIC/anon revoked | requires `auth.uid()` and updates only current user row | n/a; qualified table refs |

### Full Function Body Sources

The requested full bodies are tracked in the following local files; these links are the canonical verbatim extraction and avoid incorrectly combining superseded definitions:

- [Profile, trigger, and metrics bodies](supabase/migrations/20260804140000_harden_metrics_and_profile_provisioning.sql)
- [Daily metrics trigger body](supabase/migrations/202607110002_data_policies.sql)
- [Original wallet/reset/apply-purchase bodies](supabase/migrations/20260716193000_monetization_system.sql)
- [Final grant and consume-credit bodies](supabase/migrations/20260804120000_harden_monetization_credit_rpc.sql)
- [AI rate-limit body](supabase/migrations/20260804150000_harden_ai_proxy_rate_limit.sql)

The final definition is the last `CREATE OR REPLACE FUNCTION` for a signature. The full function bodies are not duplicated here to avoid presenting obsolete historical definitions as active code.

## 5. SECURITY DEFINER and EXECUTE Grant Risks

- `consume_monetization_credits` is intentionally DEFINER and authenticated-callable. Its body constrains all writes to `auth.uid()` and validates user inputs. Staging must verify this effective privilege and behavior.
- `ensure_profile_for_current_user` and `consume_ai_proxy_rate_limit` are DEFINER and authenticated-callable; both use the current uid. Staging must verify anonymous invocation fails.
- `handle_new_user` is DEFINER but trigger-context guarded and not granted to ordinary roles.
- `get_global_metrics` remains DEFINER, but the latest migration revokes execution from normal roles. This is the expected state: anon and ordinary authenticated calls should fail. No feature gate or cohort threshold is implemented in the final body because the function is not granted to those users.
- Wallet reset, wallet creation, grant, and verified-purchase helpers accept a target user ID. Their final tracked grants are service-role-only. User A/B cross-user calls must fail because authenticated execution is revoked, not because their historical bodies enforce ownership.

## 6. Credit Amount Validation Status

Final `consume_monetization_credits` requires a non-null integer in `1..1000`; it requires nonblank reason length `<=160` and object metadata no larger than 8192 bytes. It locks the caller wallet and raises `insufficient credits` before debit. It subtracts only positive `credit_amount` from the caller balance.

Final `grant_monetization_credits` requires a non-null integer in `1..5000`, nonblank transaction fields, and bounded object metadata. It remains service-role-only.

## 7. `apply_verified_purchase` Parameter Map

Signature: `public.apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb)`.

1. `target_user_id uuid`: recipient user ID for wallet, purchase, subscription status, and entitlement rows.
2. `product_id text`: verified ChronoSpark product ID used to select plan/credit behavior.
3. `purchase_type text`: persisted purchase type value.
4. `purchase_token_hash text`: hash used to identify duplicate purchases.
5. `order_id text`: Google Play order ID, nullable.
6. `verified_at timestamptz`: receipt verification timestamp; defaults to `now()`.
7. `expires_at timestamptz`: subscription expiry timestamp; nullable.
8. `payload jsonb`: receipt/provider payload persisted with purchase/event/status; defaults to `{}`.

The local call site in [monetization-verify](supabase/functions/monetization-verify/index.ts) sends these named parameters using a server-only secret after Google verification.

## 8. Edge Function Receipt Validation Contract

| Function | Local route inference | Contract |
| --- | --- | --- |
| `monetization-verify` | Conventional Supabase function route `/functions/v1/monetization-verify`; no separate route config found | POST only; JWT verification is configured in `supabase/config.toml`; authenticates caller through `/auth/v1/user`; receives claimed `productId`, token, and purchase type; verifies allowlisted catalog and type. |
| `ai-proxy` | Conventional `/functions/v1/ai-proxy` | POST only; JWT verification configured; validates caller through `/auth/v1/user`; calls database-backed `consume_ai_proxy_rate_limit`. |
| `account-delete` | Conventional `/functions/v1/account-delete` | POST only; JWT verification configured; requires request `userId` and optional email match the authenticated caller before server-side deletion. |

Receipt path details:

- The claimed client `productId` is received by `readVerifyRequest`.
- The Google Play subscription endpoint includes the configured Android package path and purchase token.
- `verifySubscriptionLineItem` requires active/grace subscription state, acknowledged state when supplied, array `lineItems`, an exact matching `lineItem.productId`, and future `expiryTime`.
- The verified matching product ID, not an unmatched line item, is passed to the server-only `apply_verified_purchase` call.
- One-time in-app purchase handling verifies `purchaseState === 0`; a local audit should still verify provider product binding for that API response in staging.
- `monetization-verify` still has a separate in-memory 10-request/minute limiter. It is not the shared database-backed limiter used by `ai-proxy`.

## 9. Rate-Limit Table / Function Contract

`public.ai_proxy_rate_limits` stores one row per user. Direct anon/authenticated table access is revoked. `consume_ai_proxy_rate_limit()` is authenticated-callable, requires `auth.uid()`, atomically inserts or updates that user row, uses a one-minute window, and raises after the twentieth request when the returned count exceeds 20. `ai-proxy` calls it before invoking the paid model.

Request validation limits in `ai_proxy_request_validation.ts`:

- prompt: nonblank and at most 8000 characters;
- system: at most 4000 characters;
- history: at most 8 messages, each nonblank and at most 4000 characters, aggregate at most 12000 characters;
- roles: only `user` or `assistant`;
- requested output: integer `1..1024`.

## 10. Exact Information Missing Before Seed SQL

- Explicit confirmation of the non-production staging project ref and owner approval to create temporary rows.
- A staging schema snapshot: current tables, columns/types/defaults, constraints, indexes, RLS flags, policies, grants, functions, and function configuration.
- Staging auth test-account provisioning method and test-user UUIDs; no `auth.users` seed assumptions should be made.
- Whether pgTAP and required test extensions are installed in staging.
- Staging storage bucket state and authorization to create/remove isolated test objects.
- Current remote migration history and confirmation that manually created tables have no incompatible data or keys.

## 11. Exact Information Missing Before RLS Test SQL

- Confirmed staging project ref and database test connection mechanism.
- Database role/context mechanism accepted by staging for setting JWT claims during tests.
- Two non-production authenticated identities and their UUIDs, or an approved non-production identity setup flow.
- Confirmation that the test framework can create test data transactionally and roll it back.
- Effective remote function grants and `proconfig`/`search_path`, not merely migration intent.
- Confirmation that staging has the expected `chronospark-sync` bucket and storage policy version.

## 12. Production Release Status

**NO.** Production release remains blocked. Staging is not confirmed, remote schema compatibility is unknown, and database-backed RLS, credit, profile, global-metrics, storage, and shared-rate-limit tests have not passed against a real staging project.