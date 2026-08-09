# Monetization Read Isolation Plan

**Plan only. Do not execute until read-isolation test approval is granted.**

## Scope

- `monetization_subscription_statuses`
- `monetization_wallets`
- `monetization_credit_transactions`
- `monetization_purchases`
- `monetization_entitlement_events`

Each table uses `user_id` ownership and was reported with RLS enabled, at least one policy, and an `auth.uid()` policy signal.

## Planned Checks

For each table:

1. User A can read User A rows.
2. User B cannot read User A rows.
3. User A cannot read User B rows.
4. Do not perform direct write tests unless a policy explicitly intends client writes.

## Guardrails

- Do not create seed rows without explicit approval.
- Do not use a service-role key.
- Keep valid debit, insufficient balance, grant-credit authorization, and receipt application outside this read-isolation plan.
