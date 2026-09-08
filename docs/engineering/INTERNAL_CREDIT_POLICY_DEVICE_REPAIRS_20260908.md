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

Final-source CI, the corrected signed build and Play delivery passed. Final 3021 device acceptance remains pending because the connected Moto is securely locked and still has version 3020. These checks do not certify public monetization, monthly wall-clock expiry on a phone, or a new level-20 endurance run. No monkey tests or real payment methods were used.

## Final source and internal delivery

- Frozen app source: `c5564ef2c920047a3aa1a335b46eb58b4d8d17b6`, version `4.1.0+2026083021`.
- [CI 34290932918](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34290932918) passed: 2,597 Flutter tests, 41 golden tests, 15 QA configuration tests, 16 Maestro launcher tests, and eight integration tests (startup 1, auth 6, persistence recovery 1). All manifests report zero failures, errors and skips. These launcher checks are not a claim of a new full physical-device Maestro journey run.
- Format, source/domain contracts and coverage gates passed. Passing these gates is not 100% code coverage or a guarantee that every app behavior is defect-free.
- [Signed build 34291917333](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34291917333) passed against that exact successful CI source. Local signature verification, the existing upload signer, package, version, target SDK 36, minimum SDK 24, billing permission, private two-account cohort, policy hash and disabled mock/bypass flags were independently checked. The build also verified live subscription/pack prices and backend configuration.
- AAB: `artifacts/releases/4.1.0-2026083021-internal-billing-verified/app-release.aab`, 77,926,855 bytes. SHA-256: `3dfd59e1560b22e5db70cc505dcf519efcf589e68cf962e273e3646ac7ccbbf4`.
- Google Play internal release 23, `2026083021 (4.1.0) - credit purchase repairs`, was published September 8, 2026, at 6:54 PM Central. Independent track readback showed **Available to internal testers**, latest version 2026083021. Mapping and native debug symbols were attached; the review reported no lost supported devices. No production release was created.

## Configured customer policy

| Offer | USD price | Credits |
| --- | --- | --- |
| Free | $0 | 20 per monthly allowance window |
| Premium monthly | $7.99/month | 300 per month |
| Premium annual | $69.99/year | 300 per month, not all upfront |
| Optional pack | $2.99 once | 100 purchased credits |
| Optional pack | $7.99 once | 300 purchased credits |

Included credits expire each monthly window and are spent first. Purchased credits do not expire and survive subscription expiry. No automatic top-ups or overage charges are configured. Core local planning and progress remain available at zero credits. External AI requires consent and a confirmed credit quote. Public paid AI and billing remain contained; this is the private internal billing cohort, not a public revenue launch.

## Remaining device acceptance

The Moto remains connected at the authorized wireless endpoint, but Android reports a secure lock screen. The user has been asked to unlock it. The latest package readback is still 2026083020, installed by Google Play. Do not uninstall, clear data, claim 3021 is installed, or mark the following pending checks passed:

1. Update through Play and read back version 3021, preserving the main profile's level 20 and 36,125 XP.
2. Verify the separate wallet buckets, monthly allowance and non-expiring pack disclosures on the final UI.
3. Restore old consumed-pack markers, repeat a free test pack purchase, and verify the completed-credit message without a false subscription change.
4. Verify delayed approval/rejection messages and retry recovery, distinguishing automatic Google callbacks from explicit Restore Purchases recovery.
5. Cold-start/restore, local Planner/SI smoke and app-specific crash checks.

The zero-credit, spending-order, expiry-preservation and backend purchase tests above were observed on 3020 with the deployed corrected backend; they are not substituted for these pending final-UI checks.

## Additional device and server evidence

- Purchased-credit spending: 400 to 397, included zero.
- Included-first spending with Premium: 697 to 694, included 300 to 297, purchased unchanged at 397.
- Canceled test subscription expired through Google: Free 20 plus all 397 purchased credits remained.
- Database run 34285897504: complete migration replay, 343 database contracts, 131 Edge tests, schema lint passed. Local fixture tests also passed; its server is stopped.
- Main test-account level and XP have not been changed by these billing tests. The second account retained 19 included credits and no purchases.
- A delayed-decline 300-credit test purchase produced a revoked purchase record and no credit grant. Purchased balance remained 397; the two successful packs remained granted for a combined 400 credits before spending.
