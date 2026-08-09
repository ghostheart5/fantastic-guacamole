# Receipt Mismatch Preparation

Scope: local source inspection only. No Edge Function was deployed, no Google endpoint was called, and no receipt test was generated.

## Local Contract

- Edge Function folder/name: [supabase/functions/monetization-verify](../../supabase/functions/monetization-verify).
- Likely route: conventional Supabase path `/functions/v1/monetization-verify`; deployed staging base URL and route remain unconfirmed.
- Client product ID is read as `record.productId` in `readVerifyRequest`.
- Purchase token is read as `record.purchaseToken` in `readVerifyRequest`; it is trimmed and limited to 4096 characters.
- Purchase type is read as `record.purchaseType`; it must match the local allowlisted product catalog entry.
- Subscription verification calls `verifySubscriptionLineItem(gpData, productId)`.
- [subscription_verification.ts](../../supabase/functions/_shared/subscription_verification.ts) requires active or grace subscription state, acknowledged state when present, array `lineItems`, exact `lineItem.productId === claimedProductId`, and future expiry.
- A lower-tier token claimed as a higher-tier product is rejected when no exact claimed-product line item exists.
- `applyVerifiedPurchase` is called in [index.ts](../../supabase/functions/monetization-verify/index.ts) only after a valid receipt and purchase-token binding; it invokes `apply_verified_purchase` using the function runtime secret, never a client-side key.

## Required Function Environment

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY` or `SUPABASE_ANON_KEY`
- `SUPABASE_SECRET_KEY` or `SUPABASE_SERVICE_ROLE_KEY` held only in Edge Function runtime secrets
- `ANDROID_PACKAGE_NAME`
- `GOOGLE_SERVICE_ACCOUNT_JSON` held only in Edge Function runtime secrets
- `ALLOWED_ORIGINS`

## Before Staging Receipt Mismatch Testing

- Confirm the exact staging Edge Function base URL and deployed function route.
- Confirm JWT configuration and local function version match staging.
- Provide a safe Google Play staging test receipt/token path that does not create production entitlement effects.
- Confirm staging package name/product mapping and permitted cleanup/observation process.
- Confirm the staging database-effective `apply_verified_purchase` grants and semantics.

Receipt mismatch testing remains blocked. Do not call Google, use real credentials, or create live receipt requests until these items are explicitly confirmed.