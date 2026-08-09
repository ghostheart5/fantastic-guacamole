# Receipt Edge Function Review

**Local code review only. No Edge Function was deployed and no Google endpoint was called.**

## Route and Inputs

- Function folder/name: `supabase/functions/monetization-verify`.
- Handler: `index.ts`; POST-only `serve` handler.
- Client request fields: `productId`, `purchaseToken`, `purchaseType`.
- Caller identity: extracted from the bearer token through Supabase Auth `/auth/v1/user`.

## Google Verification Path

- Product IDs must be in the local `PRODUCT_CONFIG` allow-list and match the expected purchase type.
- A server-side Google service-account secret obtains an Android Publisher access token.
- Subscription lookup uses `purchases/subscriptionsv2/tokens/{purchaseToken}`.
- One-time lookup uses `purchases/products/{productId}/tokens/{purchaseToken}`.
- For subscriptions, `verifySubscriptionLineItem` requires active/grace state, acknowledged state when supplied, a matching `lineItems[].productId`, and a future expiry.
- The local test file covers matching products, lower-tier-to-higher-tier mismatch, missing line items, expired subscriptions, and invalid subscription state.

## Mismatch and Replay Controls in the Edge Path

- Subscription lower-tier tokens claiming a higher-tier product are rejected because no matching verified line item is accepted.
- For one-time products, the claimed product ID is in the Google API path and must be an allowed product/type pair locally.
- `bindPurchaseToken` hashes the token and writes/reads `purchase_bindings` using a server-side privileged database client. A pre-existing binding is accepted only for the same user.
- The authenticated Edge caller’s ID, not a client-provided target user ID, is passed to `apply_verified_purchase`.

## Purchase Application

The Edge Function calls `apply_verified_purchase` through a server-side privileged database client only after Google response validation and token binding succeed.

## Direct Bypass Risk

The Edge path itself prevents client target-user spoofing and validates subscription product matching. It does not prevent a client from calling the database RPC directly if database grants permit that RPC. The supplied discovery reports direct anon/authenticated EXECUTE, which conflicts with local migration intent and requires deployment-state remediation/re-verification.

## Server Credential Boundary

The server-side Edge Function uses a privileged database credential from its secret environment to bind tokens and call the purchase RPC. No client-side script should access that credential.

## Open Evidence

- Confirm the deployed staging function matches this local implementation.
- Confirm deployed function route/configuration and server secret handling.
- Confirm effective staging RPC grants after hardening.
- Obtain an approved safe Google test receipt path before receipt execution tests.