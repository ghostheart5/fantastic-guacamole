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

Focused corrected Flutter tests: 43 pass, plus the new pending-notice regression (17 paywall tests pass). Edge Function gate: 131 pass, zero failures/errors/skips. New contracts cover enabled internal allowance disclosure, separate purchased balances, credit outcomes, and concurrent consumption readback including rejected voided/mismatched proofs. Live verify-receipt v22 and google-play-rtdn v20 source files exactly match their deployed correction bundles.

Final-source CI, corrected signed build, Play delivery and final device acceptance are pending. These checks do not certify public monetization, monthly wall-clock expiry on a phone, or a new level-20 endurance run. No monkey tests or real payment methods were used.
