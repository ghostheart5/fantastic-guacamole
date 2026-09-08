# Internal credit policy: device findings and corrections

Build 4.1.0+2026083020, source 4c06f1b03d740646bfae0a7038c4c62cfdb893fc, was signed, independently verified and delivered through internal release 22. Google Play updated Moto ZY22G665VG without data deletion. Level 20 and 36,125 XP were preserved.

## Verified device behavior

- Monthly $7.99, annual $69.99, 100-credit $2.99 and 300-credit $7.99 prices came from Google Play.
- A three-credit quote left the 19-credit wallet and 21 existing usage records unchanged. Confirmation spent exactly three; retrying returned no-second-charge feedback and preserved balance 16.
- Four confirmed longer requests spent four credits each, reaching zero. Another request was rejected for insufficient credits. Profile, local Smart Planner guidance and SI's on-device answer remained available at zero.
- A free Google license-test purchase of 100 credits granted exactly 100 purchased credits. The account stayed Free and the second account remained at its original 19 credits. The one-time Google notification was processed successfully.

## Findings fixed for build 2026083021

1. Internal policy discarded plan allowance metadata and hid the wallet/details even with credit tests enabled. Preserve metadata for the enabled internal credit cohort and show monthly amounts, purchased balance, no-expiry terms and exhaustion information. Billing-only contained mode still hides unusable allowances.
2. Settings showed `100 of 20 available` after a top-up. Show the total, included and purchased buckets, monthly allowance, and reset date separately.
3. The completed pack showed inactive-subscription feedback. A losing concurrent consume can race the RTDN consumer. After a failed consume, verify Google's fresh consumed state, same order, owner and test-purchase proof before reporting success. Keep credit transaction outcomes separate from subscription authority reads, including retryable failures.

4. A delayed 300-credit test order correctly granted nothing while pending and exactly 300 after approval, but its historical pending notice remained. Clear that notice when a later verified purchased balance increases, without asserting which order completed or changing subscription access. A widget regression checks unchanged-wallet persistence and completed-wallet clearing while the account stays Free.
5. A fresh returning auto-renewing monthly test purchase activated access without its initial allowance. The server now permits one verified activation for a fresh test token without optional predecessor lineage, preserving order/token idempotency and private test restrictions. Migration `20260908223215_returning_test_subscription_allowance.sql` was deployed after full replay passed. A fresh device purchase immediately recorded `purchase_activation`, 300 included credits and the unchanged 397 purchased credits at 22:37:46 UTC.
6. The earlier consumed pack's stale local owner marker could survive Restore Purchases while Premium was active and prevent repurchase. A successful Google inventory now clears only absent credit-pack markers belonging to the current account. Pending products seen in the restore stream, live purchase starts, and another account's markers remain protected. All 68 billing repository tests pass, including active-Premium recovery and stream-delivered pending preservation.
7. Delayed payment rejection also needs to supersede the historical pending notice even when neither the wallet nor subscription changes. Account-scoped transaction outcome events now update the paywall independently of access authority. Pending-to-error events clear the retry guard, and the screen replaces pending with the payment result. The focused repository, provider and paywall tests pass (97 tests).

Focused corrected Flutter tests: 43 pass, plus the new pending-notice regression (17 paywall tests pass). Edge Function gate: 131 pass, zero failures/errors/skips. New contracts cover enabled internal allowance disclosure, separate purchased balances, credit outcomes, and concurrent consumption readback including rejected voided/mismatched proofs. Live verify-receipt v22 and google-play-rtdn v20 source files exactly match their deployed correction bundles.

Final-source CI, corrected signed build, Play delivery and final device acceptance are pending. These checks do not certify public monetization, monthly wall-clock expiry on a phone, or a new level-20 endurance run. No monkey tests or real payment methods were used.

## Additional device and server evidence

- Purchased-credit spending: 400 to 397, included zero.
- Included-first spending with Premium: 697 to 694, included 300 to 297, purchased unchanged at 397.
- Canceled test subscription expired through Google: Free 20 plus all 397 purchased credits remained.
- Database run 34285897504: complete migration replay, 343 database contracts, 131 Edge tests, schema lint passed. Local fixture tests also passed; its server is stopped.
- Main test-account level and XP have not been changed by these billing tests. The second account retained 19 included credits and no purchases.
- A delayed-decline 300-credit test purchase produced a revoked purchase record and no credit grant. Purchased balance remained 397; the two successful packs remained granted for a combined 400 credits before spending.
