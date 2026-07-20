# Receipt Verification Endpoint (Stub and Contract)

## Endpoint
- Method: POST
- Path: /monetization-verify
- Content-Type: application/json
- Optional auth header: Authorization: Bearer <CHRONOSPARK_RECEIPT_VERIFY_KEY>

## Request payload
```json
{
  "productId": "chronospark_premium_monthly",
  "purchaseId": "optional-store-purchase-id",
  "transactionDate": "optional-timestamp",
  "status": "purchased",
  "verificationData": {
    "source": "play_store",
    "localVerificationData": "...",
    "serverVerificationData": "..."
  }
}
```

## Response payload
```json
{
  "valid": true,
  "entitlement": "premium",
  "productId": "chronospark_premium_monthly"
}
```

## Local stub server
Run:

```bash
node scripts/receipt_verifier_stub.js
```

Use app runtime defines:

```bash
--dart-define=CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT=http://10.0.2.2:8787/monetization-verify
--dart-define=CHRONOSPARK_RECEIPT_VERIFY_KEY=your-local-key
```

## Production implementation notes
- Replace stub validation with Google Play Developer API purchase verification.
- Store receipt verification records server-side.
- Map verified purchases to user id and entitlement status.
- Reject replayed or expired tokens.
