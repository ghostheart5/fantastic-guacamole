# Post-Migration Schema Verification

**Report only. No backend checks or RLS mutation tests were run.**

## Schema Discovery Summary

The following tables were found in `public`. Each has `user_id uuid`, RLS enabled, at least one policy, and an `auth.uid()` policy signal:

- `goals`
- `habits`
- `monetization_credit_transactions`
- `monetization_entitlement_events`
- `monetization_purchases`
- `monetization_subscription_statuses`
- `monetization_wallets`
- `purchase_bindings`
- `settings`
- `tasks`
- `user_daily_metrics`

## Ready Tables

- Core-sync RLS exact-test generation: `tasks`, `goals`, `habits`, `settings`, `purchase_bindings`, and `user_daily_metrics`.
- Monetization RLS read-isolation exact-test generation: `monetization_subscription_statuses`, `monetization_wallets`, `monetization_credit_transactions`, `monetization_purchases`, and `monetization_entitlement_events`.

## Special Cases

### `public.profiles`

- Exists and has RLS enabled.
- Policy count: `3`.
- `auth.uid()` policy signal: detected.
- `user_id` is not present.
- Classification: `NEEDS_COLUMN_MAPPING`.
- Local migration policies establish ownership through `id = auth.uid()` for SELECT, INSERT, and UPDATE. Profiles can join the RLS harness with custom ownership column `id`; do not invent a `user_id` mapping.

### `public.ai_proxy_rate_limits`

- Exists with `user_id uuid` and RLS enabled.
- Policy count: `0`.
- `auth.uid()` policy signal: not detected.
- Classification: `RPC_ONLY_TABLE_REVIEW_REQUIRED`.
- Local migrations revoke direct `anon` and `authenticated` table access, then expose only authenticated execution of `public.consume_ai_proxy_rate_limit()`. Validate the rate limit through that RPC, not direct-table RLS tests.

## Blocked Tables

No expected application table is blocked for absence. `profiles` needs its custom `id` mapping; `ai_proxy_rate_limits` remains RPC-only by design.

## Ready Backend Checks

The existing ready backend harness is `READY_TO_RUN_AFTER_ENV_CONFIRMATION` for credit zero/negative/anonymous denial, wallet/reset helper denial, profile repair/idempotency, global-metrics denial, and database-backed rate-limit behavior.

Before running it, capture a fresh post-migration [function_discovery.sql](function_discovery.sql) result that confirms the expected RPCs, signatures, and effective grants, then confirm the staging-only `.env` is complete. The only recorded `NOT_FOUND` result predates this post-migration schema discovery.

Production release remains **NO**.