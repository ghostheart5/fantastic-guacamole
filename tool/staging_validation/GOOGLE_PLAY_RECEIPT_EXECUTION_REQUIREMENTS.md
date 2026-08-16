# Google Play Receipt Execution Requirements

Status: planning only. This document authorizes no Google Play request, purchase, deployment, SQL, seed, or cleanup operation.

## Test account requirements

- Use two approved, non-production Google Play test accounts and two matching staging ChronoSpark accounts: User A and User B.
- Each account must be eligible for the configured Google Play testing track and must not be used for production purchases.
- Record only redacted account labels in evidence. Do not record passwords, access tokens, purchase tokens, service-account material, or full order IDs.

## Test product requirements

- The Android package must match the deployed function's configured package name.
- Products must be active and available to the approved test accounts in the intended test track.
- Supported identifiers are: `chronospark_premium_monthly`, `chronospark_premium_annual`, `chronospark_lifetime`, `chronospark_credits_100`, `chronospark_credits_500`, `chronospark_credits_1200`, and `chronospark_credits_3000`.
- Each scenario requires a unique, approved test purchase unless the scenario explicitly tests replay.

## Subscription requirements

- Use an acknowledged subscription test purchase whose Google response has `SUBSCRIPTION_STATE_ACTIVE` or `SUBSCRIPTION_STATE_IN_GRACE_PERIOD`.
- The response must contain a `lineItems` entry with the exact claimed subscription product ID and a future `expiryTime`.
- Use only `chronospark_premium_monthly` or `chronospark_premium_annual` with `purchaseType: subscription`.
- For expiration and invalid-state cases, obtain an approved test artifact or Play test lifecycle state. Do not fabricate a token or alter server data.

## In-app purchase requirements

- Use an approved completed in-app test purchase with `purchaseState === 0`.
- Use `purchaseType: inapp` with one of `chronospark_lifetime`, `chronospark_credits_100`, `chronospark_credits_500`, `chronospark_credits_1200`, or `chronospark_credits_3000`.
- Confirm the product is consumable/non-consumable in Google Play as intended before execution; this repository does not establish that console configuration.

## Receipt and token acquisition

1. An approved test operator completes the Google Play test purchase on the intended test track.
2. The ChronoSpark test client obtains the purchase token through its normal purchase integration.
3. The test operator records a redacted token fingerprint, product ID, purchase type, test user label, timestamp, and redacted order identifier.
4. The client sends the normal authenticated request to `POST https://retired-staging-project.invalid/functions/v1/monetization-verify`.
5. The raw token remains confined to the approved test device/runtime; it is never copied into a report, script, repository, or chat transcript.

## Product mismatch requirements

- Obtain a valid lower-tier subscription token and claim the other supported subscription product ID.
- Obtain a valid higher-tier subscription token and claim the other supported subscription product ID.
- Preserve the same purchase type and authenticated owner for each mismatch request.
- Expected prerequisite: Google returns the token data, but the local verifier rejects the missing exact matching `lineItems.productId` before token binding or RPC application.

## Replay requirements

- Reuse a single already-verified token only after its first request's evidence and cleanup disposition are approved.
- Test same-user repeat and User B use of User A's token separately.
- Capture the first and subsequent redacted request/result pairs plus no-unintended-mutation evidence.

## Expired subscription requirements

- Use a real test token whose matching line-item expiry is in the past when the request is made.
- Capture the redacted Google lifecycle evidence and the Edge result.
- Expected prerequisite: no token binding or receipt-application RPC occurs when expiry validation fails.

## Safe evidence collection

- Capture only status, `valid`, error category, product ID, purchase type, redacted order/token fingerprints, timestamps, and approved before/after user-visible state.
- Do not capture bearer tokens, service-role keys, service-account JSON, raw Google responses, or raw receipt tokens.
- Label every row with test user, scenario ID, and cleanup owner; retain evidence until the approved cleanup verification is complete.
