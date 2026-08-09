# Grant Credits Authorization Test Plan

**Staging-only denial validation. Do not run without explicit human approval.**

## Purpose

Verify that anonymous and normal authenticated callers cannot invoke `public.grant_monetization_credits`, whether targeting themselves or the other staging user. The test observes only client-visible state and has no privileged execution path.

## Function Signature

```text
public.grant_monetization_credits(
  target_user_id uuid,
  credit_amount integer,
  transaction_type text,
  transaction_source text,
  transaction_description text,
  metadata jsonb
)
```

## Expected Grants

The final hardening migration revokes all EXECUTE access from `public`, `anon`, and `authenticated`. It grants EXECUTE only to the database privileged role. This client-side harness tests no privileged role or credential.

## Expected Denial Cases

- Anonymous caller targeting User A.
- User A targeting User A.
- User A targeting User B.
- User B targeting User B.
- User B targeting User A.

Each call must return a non-2xx response. A successful invocation is a security failure.

## State-Change Checks

Before and after all denial attempts, the harness reads each caller’s own `monetization_wallets` row and own `monetization_credit_transactions` rows. It fails if a client-visible wallet balance, bonus balance, or lifetime-earned value increases, or if an additional visible credit-transaction row appears.

## Cleanup Strategy

No harness-owned data is created. Expected denials leave nothing to delete. Any detected state change is a failure requiring manual investigation; do not attempt automated cleanup because the source of the change is ambiguous.

## Intentionally Not Tested

- Privileged-role authorization or successful grants.
- Any service-role/admin credential path.
- Wallet setup, valid debit, insufficient balance, receipts, or Storage.

## Production Release Status

**NO**