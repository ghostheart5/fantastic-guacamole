# Monetization Read Isolation Tests

**Staging-only executable test design. Do not run until read-isolation test approval is granted.**

## Tables

- `monetization_subscription_statuses`
- `monetization_wallets`
- `monetization_credit_transactions`
- `monetization_purchases`
- `monetization_entitlement_events`

Each table has `user_id` ownership, RLS enabled, and an `auth.uid()` policy signal.

## Per-Table Read Checks

For each table:

1. User A reads rows where `user_id = User A UUID`; only User A-owned rows may be visible.
2. User B queries for User A rows; no User A-owned row may be visible.
3. User A queries for User B rows; no User B-owned row may be visible.
4. Do not perform direct writes unless a reviewed policy explicitly intends authenticated client writes.

## Data Preconditions

- Use naturally provisioned User A/User B records where available.
- Do not create transactions, purchases, entitlements, subscription statuses, or wallet data solely for these tests without explicit seed/setup approval.
- An empty result for an own-row read is inconclusive when no naturally provisioned row exists; record that case as `NO_OWN_ROW_AVAILABLE`, not as a failed RLS assertion.

## Guardrails

- No service-role key.
- No receipt, grant-credit, valid-debit, or insufficient-balance test in this plan.
- No production URL or account.
