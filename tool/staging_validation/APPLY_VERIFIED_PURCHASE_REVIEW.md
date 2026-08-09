# `apply_verified_purchase` Review

**Local source review only. No database or receipt endpoint was contacted.**

## Final Local Definition

The final local migration definition is:

```text
public.apply_verified_purchase(
  target_user_id uuid,
  product_id text,
  purchase_type text,
  purchase_token_hash text,
  order_id text default null,
  verified_at timestamptz default now(),
  expires_at timestamptz default null,
  payload jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public
```

No later local migration redefines this function.

## Parameters

| Parameter | Meaning |
| --- | --- |
| `target_user_id` | User to receive purchase, subscription, entitlement, and wallet effects. |
| `product_id` | Product selector for monthly, annual, lifetime, or credit packs. |
| `purchase_type` | Stored purchase category; the function does not independently validate a product/type pairing. |
| `purchase_token_hash` | Hash used to detect an existing purchase for the same user. |
| `order_id` | Google order identifier stored with purchase/subscription data. |
| `verified_at` / `expires_at` | Caller-supplied verification and subscription-expiry times. |
| `payload` | Caller-supplied purchase metadata persisted in records. |

## Security and Grants

- Security mode: `SECURITY INVOKER`.
- Search path: `public`.
- Local migration intent: revoke from `public`, then grant execute only to the privileged database role.
- Supplied staging discovery: EXECUTE is currently reported for `anon`, `authenticated`, `postgres`, and `service_role`.

This is an unresolved deployment/grant mismatch. Local migration intent is not proof of deployed grants.

## Ownership and Target Checks

The body only rejects a null `target_user_id`. It does not compare `target_user_id` with `auth.uid()`, does not require an authenticated caller, and does not inspect a verified Edge Function claim. If anon/authenticated EXECUTE is effective, the function accepts a caller-selected target user.

## Product and Token Handling

- Product IDs are mapped directly to subscription tiers or credit amounts by `if/elsif` branches.
- Unsupported product IDs raise an exception.
- The function does not contact Google or validate a token/product relationship.
- Duplicate detection checks only `(user_id, purchase_token_hash)` in `monetization_purchases`.
- The schema uniqueness constraint is likewise `(user_id, purchase_token_hash)`; `order_id` is not unique.
- A token hash is not globally bound at the database function layer. The Edge Function’s `purchase_bindings` path is separate and can be bypassed by a direct RPC caller if direct EXECUTE is effective.

## Entitlement, Wallet, and Transaction Effects

- Monthly/annual products upsert subscription status, reset allowance, and add a `subscription_grant` transaction.
- Lifetime and credit-pack products call `grant_monetization_credits`; lifetime then changes the wallet tier and allowance.
- Every non-duplicate purchase inserts `monetization_purchases` and `monetization_entitlement_events` records.

## Direct Execution Answers

1. **Can anon call directly?** Supplied discovery says yes; local migration intent says no. Treat as unsafe until effective grants are hardened and re-verified.
2. **Can authenticated users call directly?** Supplied discovery says yes; local migration intent says no. Treat as unsafe until effective grants are hardened and re-verified.
3. **Can a caller choose any target?** The body has no ownership check, so yes if direct invocation reaches the body.
4. **Can a caller choose a higher tier without server verification?** The body maps caller-supplied `product_id` directly to entitlements/credits; yes if direct invocation reaches the body.
5. **Does it verify Google validation?** No.
6. **Does it require evidence of Edge verification?** No.
7. **Does it prevent replay?** Only per-user token-hash duplication; it does not enforce global token or order uniqueness.
8. **Does it prevent applying to another user?** No body-level check.
9. **Does it rely on the Edge Function?** Yes, for Google verification, token binding, and caller-to-target identity binding.
10. **Should anon/authenticated EXECUTE be revoked?** Yes, if the Edge Function is the only intended caller.

## Security Risks

- Effective direct RPC access would bypass Google verification and token binding.
- Caller-controlled target, product, expiry, and payload values could create unauthorized benefits.
- Token/order replay prevention is incomplete in the database layer.
- Security-invoker dependency permissions might make some direct calls fail, but this is not a security control to rely on.

## Production Release Status

**NO**