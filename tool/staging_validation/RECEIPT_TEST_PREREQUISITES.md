# Receipt Test Prerequisites

## Deployed Edge Function

- Required function name: `monetization-verify`.
- Required route: `POST /functions/v1/monetization-verify` on confirmed staging only.
- Confirm the deployed function matches the reviewed source before testing.

## Staging Environment

The deployed Edge Function requires these server-side environment variables to be configured without exposing their values in client scripts or test records:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY` or `SUPABASE_ANON_KEY`
- `SUPABASE_SECRET_KEY` or `SUPABASE_SERVICE_ROLE_KEY`, server-side only
- `GOOGLE_SERVICE_ACCOUNT_JSON`, server-side only
- `ANDROID_PACKAGE_NAME`
- `ALLOWED_ORIGINS`

Client-side requests use an authenticated normal-user session and must never contain a privileged database key.

## Google Play Test Prerequisites

- A Google Play Console test track for package `com.ghostheart5.chronospark`.
- A licensed tester account enrolled in the selected test track.
- A staging-safe test device/account able to acquire the approved test purchase.
- An approved test purchase/token path, including replay and cleanup ownership.
- Confirmation that test purchases do not target production release evidence or credentials.

## Allowed Products

- `chronospark_premium_monthly` - subscription
- `chronospark_premium_annual` - subscription
- `chronospark_lifetime` - in-app product
- `chronospark_credits_100` - in-app product
- `chronospark_credits_500` - in-app product
- `chronospark_credits_1200` - in-app product
- `chronospark_credits_3000` - in-app product

## Cleanup Contract

- Define the test user, product, expected order/token hash, and ownership before execution.
- Capture before/after wallet, purchase, entitlement, and token-binding evidence.
- Document the approved cleanup owner and process for any test-created records or test-purchase lifecycle action.
- Do not delete, refund, revoke, or modify records automatically from client scripts.

## Required Evidence Capture

- Captured grant verification result and bypass transcript.
- Edge Function route, request metadata, and response result without raw credentials or purchase tokens.
- Product-mismatch, replay, entitlement, wallet, and cleanup outcomes.
- Final receipt status and unresolved blockers.

Production release remains **NO**.