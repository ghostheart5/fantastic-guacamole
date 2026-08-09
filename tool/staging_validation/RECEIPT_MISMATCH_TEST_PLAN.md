# Receipt Mismatch Test Plan

Status: execution plan only. Do not execute until the Google Play receipt requirements and cleanup approval contract are satisfied.

| Scenario | Preconditions | Expected Edge Function behavior | Expected RPC behavior | Expected entitlement and wallet result | Cleanup impact |
| --- | --- | --- | --- | --- | --- |
| Valid product token | Approved User A, unique eligible Play test token, exact supported product ID/type, approved cleanup owner. | Verifies with Google, binds token to User A, returns `valid: true` when application succeeds. | `apply_verified_purchase` is invoked as server-side service role. | Product-specific purchase, entitlement, and wallet effects occur. | `ADMIN_REQUIRED`.
| Lower-tier token claiming higher-tier product | Valid monthly token claimed as annual; same User A and subscription type. | Exact `lineItems.productId` check fails; returns invalid. | Not invoked. | No entitlement or wallet mutation. | `AUTOMATIC` after no-mutation evidence.
| Higher-tier token claiming lower-tier product | Valid annual token claimed as monthly; same User A and subscription type. | Exact `lineItems.productId` check fails; returns invalid. | Not invoked. | No entitlement or wallet mutation. | `AUTOMATIC` after no-mutation evidence.
| Invalid product ID | Authenticated user and non-empty token; unsupported product ID. | Rejects request validation with HTTP 400. | Not invoked. | No entitlement or wallet mutation. | `AUTOMATIC` after no-mutation evidence.
| Expired subscription | Approved real subscription token with matching product but past expiry. | Subscription verifier returns invalid. | Not invoked. | No entitlement or wallet mutation. | `AUTOMATIC` after no-mutation evidence.
| Invalid subscription state | Approved real subscription token with a state outside active/grace period. | Subscription verifier returns invalid. | Not invoked. | No entitlement or wallet mutation. | `AUTOMATIC` after no-mutation evidence.
| Missing `lineItems` | Approved test artifact/lifecycle response without a usable matching line item; do not mock production data. | Subscription verifier returns invalid. | Not invoked. | No entitlement or wallet mutation. | `AUTOMATIC` after no-mutation evidence.
| Replay attempt | A first User A verification completed and its state/evidence is captured. | Same-user repeated token proceeds only to token binding; application result must be idempotent. Cross-user token must fail token binding. | Same-user duplicate returns `applied: false, duplicate: true`; cross-user is not invoked. | No second grant; no User B entitlement or wallet mutation. | First request is `ADMIN_REQUIRED`; replay requests are `AUTOMATIC` after no-mutation evidence.
| Wrong user attempt | User A owns a prior bound token; User B is authenticated. | Token binding rejects User B. | Not invoked. | No User B purchase, entitlement, subscription, or wallet change. | `AUTOMATIC` after no-mutation evidence.

Required evidence for every scenario: redacted user label, product/type, request timestamp, HTTP status, `valid` and error category, redacted token/order correlation, and approved user-visible before/after state. Never retain raw receipt tokens or secrets.
