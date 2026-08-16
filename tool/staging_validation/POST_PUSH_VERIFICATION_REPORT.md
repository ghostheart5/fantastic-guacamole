# Post-Push Verification Report

**Verification report. The documented staging-only Core-Sync RLS run completed with 63 passes, 0 failures, and 5 expected skips. `apply_verified_purchase` grant verification passed and the captured bypass transcript passed with 19 PASS, 0 FAIL, and 0 SKIP. Receipt mismatch validation remains blocked by deployed route confirmation, safe Google Play test-purchase path, and cleanup contract. No Storage, deployment, or unrelated seed activity was run.**

## Migration Push Status

Migration push is reported complete for confirmed staging project `RETIRED_STAGING_PROJECT`.

## Schema Discovery Result

Schema discovery confirms the following `public` tables exist with `user_id uuid`, RLS enabled, at least one policy, and an `auth.uid()` policy signal:

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

## Function Discovery Status

The ready backend harness completed successfully against confirmed staging, demonstrating the deployed RPC paths needed by the harness are available. A catalog-level post-migration function discovery export remains useful for signature and grant documentation, but the prior pre-migration `NOT_FOUND` result must not be treated as current state.

## Core-Sync RLS

- `tasks`
- `goals`
- `habits`
- `settings`
- `purchase_bindings`
- `user_daily_metrics`

Status: `PASSED`.

## Monetization Read Isolation

- `monetization_subscription_statuses`
- `monetization_wallets`
- `monetization_credit_transactions`
- `monetization_purchases`
- `monetization_entitlement_events`

Status: `PASSED_WITH_EXPECTED_OWN_ROW_SKIPS`. Cross-user denial passed; own-record visibility skipped for five tables because User A has no naturally provisioned records. No direct writes were performed.

## Profiles RLS

- Status: `PASSED`.
- Ownership is `id = auth.uid()` for SELECT, INSERT, and UPDATE.

## Special Table Mappings

- `ai_proxy_rate_limits`: `RPC_ONLY_TABLE_REVIEW_REQUIRED`; direct client table access is revoked. Validate only through `consume_ai_proxy_rate_limit()` after fresh function discovery confirmation.

## Environment Prerequisites

The local staging `.env` shape is ready without exposing values:

- All required variables are present and non-empty.
- `STAGING_SUPABASE_URL` contains `RETIRED_STAGING_PROJECT`.
- The URL does not end with `/rest/v1/`.
- Both user UUIDs are valid and distinct.

## Result Status

- `CORE_SYNC_RLS`: `PASSED`
- `PROFILES_RLS`: `PASSED`
- `MONETIZATION_READ_ISOLATION`: `PASSED_WITH_EXPECTED_OWN_ROW_SKIPS`
- `READY_BACKEND_CHECKS`: `PASSED_WITH_EXPECTED_SKIPS`
- `APPLY_VERIFIED_PURCHASE_GRANT_VERIFICATION`: `PASSED`
- `APPLY_VERIFIED_PURCHASE_DIRECT_BYPASS_VERIFICATION`: `PASSED`

## Remaining Blocked Categories

- Valid/insufficient debit tests: `BLOCKED_NEEDS_APPROVED_WALLET_SETUP_AND_CLEANUP`.
- `grant_monetization_credits` authorization: `BLOCKED_NEEDS_EXACT_AUTHORIZATION_TEST`.
- Receipt mismatch / `apply_verified_purchase`: `BLOCKED_PENDING_EDGE_FUNCTION_ROUTE_GOOGLE_TEST_PATH_AND_CLEANUP_CONTRACT`.
- Storage policy-contract validation: `BLOCKED_NEEDS_BUCKET_PATH_POLICY_CONTRACT`.
- Monetization own-record visibility: `PARTIALLY_BLOCKED_NEEDS_NATURALLY_PROVISIONED_OR_APPROVED_TEST_ROWS`.

## Ready Backend Checks

Status: `PASSED_WITH_EXPECTED_SKIPS`.

- No failures occurred.
- Four skips remain intentionally blocked.
- The run does not cover core-sync RLS, spoofed upserts, receipt mismatch, Storage, valid debit, insufficient balance, or grant-credit authorization.

The following checks passed:

- credit zero/negative/anonymous denial
- wallet/reset helper denial
- profile repair/idempotency
- global metrics denial
- database-backed rate-limit RPC behavior

## Next Phase

Follow [NEXT_BACKEND_VALIDATION_PHASE.md](NEXT_BACKEND_VALIDATION_PHASE.md). Keep `ai_proxy_rate_limits` RPC-only.

## Production Release Status

**NO**
