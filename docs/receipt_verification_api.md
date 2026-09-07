# Google Play receipt verification

The shipping endpoint is `POST /functions/v1/verify-receipt` on the configured
Supabase project. It requires the signed-in user's bearer access token and JSON.
There is no shared client-side receipt secret and no shipping stub verifier.

```json
{
  "productId": "chronospark_premium_monthly",
  "purchaseToken": "<Google Play purchase token>",
  "purchaseType": "subscription",
  "requireTestPurchase": true
}
```

Products are `chronospark_premium_monthly` and `chronospark_premium_annual`.
Internal billing candidates always send `requireTestPurchase: true`. Other
clients may omit the optional boolean. Never log or publish purchase tokens.

The function verifies the purchase with Google's `purchases.subscriptionsv2`
API, validates product, state, expiry and account binding, acknowledges the
purchase when required, then reconciles durable subscription authority.
Client-asserted purchase success cannot grant access.

When test purchase is required, the function rejects a Google response without
its `testPurchase` object before binding, acknowledgement or reconciliation.
It returns HTTP 409 and `license_test_purchase_required`. This check does not
prevent Google from charging a real payment method: the purchasing Google
account must be a license tester and the payment sheet must show a test method.

Successful responses include `valid: true`, `testPurchase` (a boolean),
`acknowledged: true`, authoritative `expiryTimeMs`, `status`, `productId`,
`planId` and, when available, `orderId` and `eventType`. Access statuses are
`active`, `grace` and `cancelled` (access until expiry). Retryable provider,
acknowledgement and database failures do not report success.

The client independently requires the verified test marker in license-test
builds, a matching product, a supported status and authoritative expiry.
`SubscriptionState.isTesting` continues to mean a mock/bypass; a verified Google
test purchase does not set that field.

Contract headers are `X-ChronoSpark-Contract: verify-receipt-v2` and
`X-ChronoSpark-Test-Purchase-Guard: v1`. Candidate preflight checks the deployed
guard along with catalog prices and RTDN push authentication.

Official references: [Google Play billing tests](https://developer.android.com/google/play/billing/test)
and [SubscriptionPurchaseV2](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2).
