# Receipt Edge Function Route Candidates

## `monetization-verify`

1. Function folder: `supabase/functions/monetization-verify`.
2. Likely deployed route: `POST /functions/v1/monetization-verify`.
3. Request method: `POST`; `OPTIONS` is handled for CORS.
4. Request body fields: `productId`, `purchaseToken`, `purchaseType`.
5. Required auth: bearer-token authentication resolved through Supabase Auth; local `config.toml` enables JWT verification.
6. `productId` is read from the parsed request body and checked against the local allow-list and expected purchase type.
7. `purchaseToken` is read from the parsed request body, trimmed, hashed for binding, and sent server-side to Google for verification.
8. Google validation occurs through Android Publisher API purchase-token endpoints after server-side service-account authentication.
9. Subscription `lineItems[].productId` is compared with the claimed product in `verifySubscriptionLineItem`.
10. `apply_verified_purchase` is called from the server-side `applyVerifiedPurchase` helper only after verification and token binding succeed.
11. Required environment variables: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` or `SUPABASE_ANON_KEY`, `SUPABASE_SECRET_KEY` or `SUPABASE_SERVICE_ROLE_KEY` server-side only, `GOOGLE_SERVICE_ACCOUNT_JSON` server-side only, `ANDROID_PACKAGE_NAME`, and `ALLOWED_ORIGINS`.
12. Local deployability: **appears deployable**. Actual staging deployment and route availability require separate confirmation.

## `verify-receipt`

1. Function folder: `supabase/functions/verify-receipt`.
2. Likely deployed route: not determinable.
3. Request method: not determinable.
4. Request body fields: not determinable.
5. Required auth: not determinable.
6. Product handling: not determinable.
7. Purchase-token handling: not determinable.
8. Google validation: not determinable.
9. Line-item validation: not determinable.
10. RPC application: not determinable.
11. Required environment variables: not determinable.
12. Local deployability: **not deployable as found**; the folder is empty.

Production release remains **NO**.