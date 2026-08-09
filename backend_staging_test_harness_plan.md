# ChronoSpark Staging Test Harness Plan

Scope: planning only, based exclusively on [backend_staging_inventory_report.md](backend_staging_inventory_report.md). This plan does not contact, mutate, or identify a Supabase project. `READY_FOR_EXACT_TESTS` means the local inventory contains enough object and contract detail to author a test; execution is still prohibited until the target is explicitly confirmed as staging.

## Required Staging Identities and Configuration

Required non-production accounts:

- `staging_user_a`: authenticated user A; used to create and read A-owned data.
- `staging_user_b`: authenticated user B; used to prove cross-user denial.

Required placeholder-only environment variables:

```text
STAGING_SUPABASE_URL=<staging-project-url>
STAGING_SUPABASE_ANON_KEY=<staging-anon-or-publishable-key>
STAGING_USER_A_EMAIL=<non-production-email>
STAGING_USER_A_PASSWORD=<non-production-password>
STAGING_USER_B_EMAIL=<non-production-email>
STAGING_USER_B_PASSWORD=<non-production-password>
STAGING_EDGE_FUNCTION_URL=<staging-edge-function-base-url-if-needed>
```

No client-side script may use a service-role or secret key.

## Confirmed Object Inventory

### Tables

The report confirms these local migration objects. Column descriptions below are exactly as detailed in the report; an abbreviated description is not an authorization to invent omitted columns, defaults, or required fields.

| Table | Confirmed columns / constraints | Ownership | RLS | Policies | Grants |
| --- | --- | --- | --- | --- | --- |
| `public.profiles` | `id uuid`, `email text`, `full_name text`, `avatar_url text`, timestamps | `id` | enabled | authenticated select/insert/update own-row | authenticated SELECT/INSERT/UPDATE |
| `public.purchase_bindings` | `token_hash text`, `user_id uuid`, `product_id text`, `created_at timestamptz` | `user_id` | enabled | authenticated select/insert/update/delete own-row | authenticated CRUD |
| `public.user_daily_metrics` | `device_id text`, `date date`, `user_id uuid`, counters, `momentum_peak double precision`, timestamps | `user_id` | enabled | authenticated select/insert/update own-row | authenticated SELECT/INSERT/UPDATE |
| `public.tasks` | `user_id uuid`, `id text`, title/description/kind, priority/difficulty/energy, schedule/goal/subtasks/recurrence, completion/cancellation/due/duration, timestamps/deleted marker | `user_id` | enabled | authenticated select/insert/update/delete own-row | authenticated CRUD |
| `public.goals` | `user_id uuid`, `id text`, title/description/target/color/status, completion/archive/timestamps/deleted marker | `user_id` | enabled | authenticated select/insert/update/delete own-row | authenticated CRUD |
| `public.habits` | `user_id uuid`, `id text`, title/description/cadence/count/status/active, timestamps/deleted marker | `user_id` | enabled | authenticated select/insert/update/delete own-row | authenticated CRUD |
| `public.settings` | `user_id uuid`, `id text`, booleans, `theme_mode text`, timestamps/deleted marker | `user_id` | enabled | authenticated select/insert/update/delete own-row | authenticated CRUD |
| `public.ai_proxy_rate_limits` | `user_id uuid`, `window_started_at timestamptz`, `request_count integer`, `updated_at timestamptz` | `user_id` | enabled | none found | anon/authenticated table access revoked |
| `public.monetization_subscription_statuses` | user, plan/product/status, active/source/renewal, credits, dates, order/token hash/metadata | `user_id` | enabled | authenticated select own | authenticated SELECT |
| `public.monetization_wallets` | user, balances/allowance/bonus/period/lifetime/tier/end/timestamp | `user_id` | enabled | authenticated select own | authenticated SELECT |
| `public.monetization_credit_transactions` | uuid id, user, type/amount/balance/source/description/metadata/date | `user_id` | enabled | authenticated select own | authenticated SELECT |
| `public.monetization_purchases` | uuid id, user, product/type/platform/state/token/order/credits/plan/payload/dates | `user_id` | enabled | authenticated select own | authenticated SELECT |
| `public.monetization_entitlement_events` | uuid id, user, event/plan/product/active/dates/metadata | `user_id` | enabled | authenticated select own | authenticated SELECT |
| `storage.objects` for private `chronospark-sync` | managed table; report confirms bucket and user-ID first path segment policy, not a full column list | path prefix | policy-backed | authenticated select/insert/update/delete own prefix | not reported |

### Functions / RPCs

| Confirmed signature | Security / search path | Grants and revocations | Caller binding / validation | Server-only expectation |
| --- | --- | --- | --- | --- |
| `handle_new_user()` | DEFINER; `public, pg_temp` | PostgreSQL, service role, `supabase_auth_admin`; ordinary roles revoked | trigger-context check; no `auth.uid()` | trigger-only |
| `ensure_profile_for_current_user()` | DEFINER; `public, pg_temp` | authenticated; PUBLIC/anon revoked | requires `auth.uid()`; creates/selects only current profile | no |
| `set_user_daily_metrics_updated_at()` | INVOKER; no path setting reported | no direct grant reported; trigger function | fills `NEW.user_id` from `auth.uid()` only when null | trigger-only |
| `get_global_metrics()` | DEFINER; `public, pg_temp` | PUBLIC/anon/authenticated revoked | no uid check in final body | internal/admin only if separately granted remotely |
| `ensure_monetization_wallet(target_user_id uuid default null)` | INVOKER; historical `public` | service role only | arbitrary target accepted; no equality check | yes |
| `reset_monetization_allowance(target_user_id uuid default null)` | INVOKER; historical `public` | service role only | arbitrary target accepted; no equality check | yes |
| `grant_monetization_credits(...)` | INVOKER; `public, pg_temp` | service role only | target not constrained; amount `1..5000`; transaction fields and metadata validated | yes; exact signature is not reproduced in the report |
| `consume_monetization_credits(integer, text, jsonb)` | DEFINER; `public, pg_temp` | authenticated; PUBLIC/anon revoked | requires `auth.uid()`; no target parameter; amount `1..1000`, nonblank reason max 160, bounded object metadata | no |
| `apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb)` | INVOKER; historical `public` | service role only | arbitrary target accepted; no generic amount input | yes |
| `consume_ai_proxy_rate_limit()` | DEFINER; `public, pg_temp` | authenticated; PUBLIC/anon revoked | requires `auth.uid()`; operates on caller row; twentieth request permitted, next request rejected in one-minute window | no |

### Edge Function Contract

| Function/path | Confirmed behavior |
| --- | --- |
| `supabase/functions/monetization-verify` | POST; JWT verification configured; authenticates through `/auth/v1/user`; accepts `productId`, purchase token, and purchase type; route is conventionally `/functions/v1/monetization-verify`, but deployed staging URL is not confirmed. |
| Receipt validation path | validates an allowlisted product catalog/type, requests Google Play verification, binds token hash to caller, then calls `apply_verified_purchase` with a server-only secret. |
| Google Play subscription product validation | requires active/grace state, acknowledged state when provided, an array of line items, an exact matching line-item `productId`, and future expiry. The verified matching product is applied. |
| Google Play one-time behavior | requires `purchaseState === 0`; report calls for a staging check of provider product binding. |
| Receipt rate limit | in-memory, per function instance: 10 requests per minute. It is not the database-backed AI rate limiter. |
| `supabase/functions/ai-proxy` | POST; JWT verification configured; authenticates through `/auth/v1/user`; invokes shared `consume_ai_proxy_rate_limit()` before the upstream model call. |
| AI payload limits | prompt <= 8000; system <= 4000; history <= 8 items, each <= 4000 and total <= 12000; roles only `user`/`assistant`; `maxTokens` integer `1..1024`. |
| `supabase/functions/account-delete` | POST; JWT verification configured; supplied `userId` and optional email must match caller before server-side deletion. |

## Exact-Test Readiness

| Test category | Classification | Reason |
| --- | --- | --- |
| Cross-user RLS | `TABLE_MISSING_OR_WRONG_SCHEMA` | Preflight returned `exists=false` for expected public tables. Do not generate seed SQL or run RLS tests until schema discovery identifies the staging schema and definitions. |
| Spoofed `user_id` upsert denial | `TABLE_MISSING_OR_WRONG_SCHEMA` | Expected public core tables are absent in the preflight result. Do not generate upsert payloads until migration history and schema discovery resolve the target schema. |
| Credit consume/debit | `READY_FOR_EXACT_TESTS` | Exact RPC signature, caller binding, validation range, and authenticated read access to the wallet are confirmed. |
| Privileged grant/reset denial | `READY_FOR_EXACT_TESTS` | Exact wallet/reset signatures and authenticated execution revocations are confirmed. `grant_monetization_credits` denial can be specified only after its exact signature is re-extracted from its source body. |
| Profile provisioning/repair | `READY_FOR_EXACT_TESTS` | `ensure_profile_for_current_user()` is exact, authenticated-callable, and uid-bound; anon is revoked. |
| Global metrics authorization | `READY_FOR_EXACT_TESTS` | Exact zero-argument function and final revocation from PUBLIC/anon/authenticated are confirmed. |
| Shared DB-backed rate limit | `READY_FOR_EXACT_TESTS` | Exact zero-argument RPC, caller binding, and 20-per-minute behavior are confirmed. |
| Receipt mismatch | `NEEDS_EDGE_FUNCTION_ROUTE` | Local route convention and contract are known, but the staging function base URL and a staging-safe Google test receipt path are not confirmed. |
| Storage prefix denial | `NEEDS_COLUMNS` | The policy predicate is known, but the report does not confirm the managed `storage.objects` insert/API field contract needed to create an exact test object. |

Every category also requires `NEEDS_STAGING_CONFIRMATION` before execution. That is an execution gate, not a reason to invent missing SQL details.

## Test Category Outlines

### Cross-User RLS

- Objective: prove user A cannot read, insert, update, or delete user B-owned rows.
- Objects: `tasks`, `goals`, `habits`, `settings`, `profiles`, `purchase_bindings`, `user_daily_metrics`, and monetization read tables where appropriate.
- Expected success: each user accesses only its own rows.
- Expected failure: cross-user reads return no rows; cross-user writes fail RLS.
- Exact prerequisites: `TABLE_MISSING_OR_WRONG_SCHEMA` must be resolved with migration history and schema discovery, then confirm schema/defaults, A/B UUIDs, isolated test IDs, and rollback/cleanup process.
- Exact SQL/API calls now: no, `TABLE_MISSING_OR_WRONG_SCHEMA`.

### Spoofed `user_id` Upsert Denial

- Objective: prove user A cannot submit an A-authenticated core-sync upsert containing user B's `user_id`.
- Objects: `tasks`, `goals`, `habits`, `settings` and the client-facing REST/RPC/upsert path used in staging.
- Expected success: A can create/update an A-owned row using a valid minimal payload.
- Expected failure: an A token with B's `user_id` is rejected; B's row remains unchanged.
- Exact prerequisites: `TABLE_MISSING_OR_WRONG_SCHEMA` must be resolved with migration history and schema discovery, then confirm Data API exposure and exact valid minimum payload/default fields.
- Exact SQL/API calls now: no, `TABLE_MISSING_OR_WRONG_SCHEMA`.

### Credit Negative, Zero, and Valid Debit

- Objective: prove only positive debit amounts affect the caller wallet and a valid debit applies exactly once.
- Objects: `consume_monetization_credits(integer, text, jsonb)`, `monetization_wallets`, `monetization_credit_transactions`.
- Expected success: authenticated caller debit in `1..1000` succeeds and lowers only the caller balance once.
- Expected failure: negative and zero amounts fail; unauthenticated invocation fails; user A cannot affect user B because no target parameter exists.
- Exact prerequisites: confirmed staging project, A/B credentials, an isolated wallet state or approved fresh-user flow, and a cleanup/rollback method.
- Exact SQL/API calls now: yes, `READY_FOR_EXACT_TESTS`; do not execute until staging confirmation.

### Privileged Helper RPC Denial

- Objective: prove normal authenticated users cannot invoke cross-user wallet mutation helpers.
- Objects: `ensure_monetization_wallet(target_user_id uuid default null)`, `reset_monetization_allowance(target_user_id uuid default null)`, `grant_monetization_credits(...)`, `apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb)`.
- Expected success: none for normal users; expected valid use is only intentionally authorized server/internal code.
- Expected failure: user A cannot modify B and user B cannot modify A; reset/grant helpers reject normal authenticated calls.
- Exact prerequisites: confirmed staging function privileges; exact `grant_monetization_credits` signature before testing that specific function.
- Exact SQL/API calls now: wallet/reset/apply denial yes; grant denial remains `NEEDS_FUNCTION_BODY` for its omitted exact signature.

### Global Metrics Access Control

- Objective: prove global aggregates are unavailable to public and ordinary authenticated callers.
- Objects: `get_global_metrics()`.
- Expected success: only an explicitly authorized internal/admin path may succeed, if such a grant is intentionally configured and separately approved.
- Expected failure: anon fails; normal authenticated user fails. No test may treat authenticated success as expected absent an explicit future feature gate or cohort threshold.
- Exact prerequisites: confirmed staging grants and a permitted method for testing anon and authenticated contexts.
- Exact SQL/API calls now: yes, `READY_FOR_EXACT_TESTS`.

### Profile Repair and Provisioning

- Objective: verify a valid authenticated user can repair only its own missing profile and no caller can repair another user's profile.
- Objects: `ensure_profile_for_current_user()`, `profiles`, `handle_new_user()`.
- Expected success: authenticated caller's missing profile is created or returned idempotently.
- Expected failure: anon call fails; no user-supplied target ID exists to repair another profile; signup-trigger behavior is tested only through approved non-production user provisioning.
- Exact prerequisites: approved creation of a new staging user or an existing isolated user without a profile, plus cleanup authorization.
- Exact SQL/API calls now: repair RPC yes, `READY_FOR_EXACT_TESTS`; trigger lifecycle test needs staging user-provisioning approval.

### Shared DB-Backed Rate Limit

- Objective: verify the shared database limiter permits the first 20 calls in its one-minute window and rejects the next call for the same authenticated user.
- Objects: `consume_ai_proxy_rate_limit()`, `ai_proxy_rate_limits`, optionally `ai-proxy`.
- Expected success: first 20 authenticated RPC calls succeed.
- Expected failure: call 21 fails with the configured rate-limit error; anon fails; user B has an independent counter.
- Exact prerequisites: fresh or resettable A/B staging rate-limit rows, timing control, and cleanup/rollback method.
- Exact SQL/API calls now: yes, `READY_FOR_EXACT_TESTS`; direct-table manipulation is not permitted because authenticated grants are revoked.

### Receipt Product Mismatch

- Objective: prove a claimed subscription product is not applied unless the Google response contains an exact matching active/grace, acknowledged-if-present, unexpired line item.
- Objects: `monetization-verify`, `verifySubscriptionLineItem`, `apply_verified_purchase` server call, `purchase_bindings`.
- Expected success: matching staging-safe receipt product is processed only through the Edge Function.
- Expected failure: mismatched line item, expired line item, invalid state, and wrong purchase type do not apply entitlement or credits.
- Exact prerequisites: confirmed staging Edge Function URL, deployed function version/configuration, a staging-safe Google verification fixture or approved test receipt, authenticated test session, and observation/cleanup procedure.
- Exact SQL/API calls now: no, `NEEDS_EDGE_FUNCTION_ROUTE`.

### Storage Prefix Denial

- Objective: prove a user cannot access or upload an object under another user's first path segment in private bucket `chronospark-sync`.
- Objects: `storage.objects` policies for `chronospark-sync`.
- Expected success: user A can operate only under `A_UUID/...`; user B independently uses `B_UUID/...`.
- Expected failure: A cannot create, read, update, or delete `B_UUID/...`.
- Exact prerequisites: staging bucket confirmation, exact supported Storage API/object field contract, A/B UUIDs, and approved cleanup.
- Exact SQL/API calls now: no, `NEEDS_COLUMNS`.

## Missing Information Before Executable Scripts

### Table Columns

- Exhaustive staging columns, nullability, defaults, and constraints for `tasks`, `goals`, `habits`, `settings`, `user_daily_metrics`, and each monetization table.
- Confirmed minimal valid insert/upsert payloads for the Data API.
- Managed `storage.objects` object/API field contract for the selected test method.

### RPC Function Body / Parameter Meaning

- Exact `grant_monetization_credits` signature and parameter meanings, which are abbreviated as `...` in the inventory report.
- Confirmed staging-effective bodies, owners, `proconfig`, and grants for every function because local migration intent is not live proof.

### Edge Function URL / Route

- Explicit confirmed staging base URL for `monetization-verify` and `ai-proxy`.
- Confirmation that the conventional function route is deployed and JWT configuration matches local tracked config.
- A staging-safe Google Play receipt/fixture strategy for mismatch tests.

### Staging Project Confirmation

- Explicit project ref/name confirmation that the target is staging, plus authorization to run tests there.
- Staging migration history and schema/policy/grant snapshot.
- Approved rollback or cleanup procedure for all test data.

### Test User Credentials

- Credentials for `staging_user_a` and `staging_user_b`, provided through a secure channel outside this document.
- Their UUIDs, verified-auth status, and an approved provisioning/reset procedure.

### Storage Bucket / Policy Information

- Confirmation that private bucket `chronospark-sync` exists in staging.
- Effective staging `storage.objects` policies and available Storage API operations.

### Rate-Limit Table / Function Details

- Confirmation that the final staging `consume_ai_proxy_rate_limit()` body, grants, and one-minute/20-request threshold match the inventory.
- A safe way to begin with clean per-user rate-limit rows without bypassing RLS or using a client-side service-role key.

## Production Release Status

**NO.** Production release is not allowed until a confirmed staging environment passes database, RLS, security, monetization, storage where applicable, and shared rate-limit tests.