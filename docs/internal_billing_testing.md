# Internal Google Play billing test preparation

## Current candidate instructions - September 9, 2026

Use the reviewed source commit for `4.1.0+2026083022` and the existing package
`com.ghostheart5.chronospark`. The initial September 7 setup below is historical;
its prices, allowance model, feature availability and version are superseded.

The current approved catalog is enforced by
`scripts/verify_internal_billing_backend.mjs` and migration
`20260908205414_monthly_allowances_and_credit_topups.sql`:

| Product | Base plan | Expected US catalog price | Included credits |
| --- | --- | --- | --- |
| `chronospark_premium_monthly` | `monthly` | USD 7.99/month | 300 each month |
| `chronospark_premium_annual` | `annual` | USD 69.99/year | 300 each month |
| `chronospark_credits_100` | One-time | USD 2.99 | 100 non-expiring credits |
| `chronospark_credits_300` | One-time | USD 7.99 | 300 non-expiring credits |

The free monthly allowance is 20 credits. Unused monthly allowances expire;
purchased top-up credits do not. Subscription access does not make AI usage
unlimited. A depleted wallet must prevent a chargeable action until a monthly
refill or an explicitly purchased top-up provides enough credits. These are
approved configuration values, not proof of a fresh Play Console readback.
The preflight must independently match the active Play and backend catalogs.

The public configuration remains contained. The signed internal profile enables
real Google Play test billing and separately gated AI/credit behavior only for
the verified private cohort. No premium access or wallet balance may be granted
by a client bypass. Use a Google license tester and a Google **test** payment
instrument; being an internal-track tester alone does not make purchases free.
The optional Planner explanation remains unavailable until its independent
provider, privacy, safety and evaluation readiness gates pass. Device speech
recognition is a separate optional device-provider feature and does not spend
ChronoSpark AI credits.

Use the guarded candidate workflow on the allowed tooling branch with an exact
app source SHA. Require successful exact-source CI and separate database/Edge
gate receipts, then a fresh backend preflight before building. Public legal-page
publication and Play upload are held by the current user instruction. A passing
host suite or preflight does not establish Google purchase lifecycle behavior,
actual credit spending, a Play-signed update, or native device acceptance.

## Historical initial setup - September 7, 2026

Prepared 2026-09-07 UTC. Target: signed Android release candidate
`4.1.0+2026083013`, package `com.ghostheart5.chronospark`, existing upload key and
existing Google Play internal-testing track. Stop before the AAB build stage.
This checkpoint does not approve a public release or paid AI-credit launch.

## Approved catalog and verified external setup

| Product | Base plan | Auto-renewal | US price |
| --- | --- | --- | --- |
| `chronospark_premium_monthly` | `monthly` | Monthly | USD 4.99 |
| `chronospark_premium_annual` | `annual` | Yearly | USD 39.99 |

Both base plans were activated and read back in Play Console. Initial
availability is United States only, without trials or introductory offers.
Google's default grace and automatic account-hold settings were retained.
The dedicated `ChronoSpark billing test` license-tester list contains the one
approved Google account; the list is selected and the settings were saved.
The purchasing account and test payment method still require device verification.

The backend catalog migration `20260907032502_align_internal_billing_catalog`
was applied and read back. Prices are 4,990,000 and 39,990,000 USD micros.
Legacy allowance metadata now matches the existing authoritative grants:
300/monthly paid period and 360/annual paid period. This does not add a monthly
annual-plan refill, change wallets, or authorize credit spending. Final commercial
credit quantities and costs remain a separate product decision.

A Google Play test RTDN arrived on 2026-09-07 at 03:04:37 UTC and was processed
without a failure code. This verifies test-event delivery, not renewal behavior.
The receipt verifier was updated to version 13 with the license-test guard and
a normalized credential fingerprint for preflight/deployment comparison;
all five deployed bundle source files matched the local source after LF
normalization. Database RLS and service-controlled entitlements remain in use.

The existing backend service account has approved ChronoSpark-only app/quality
read access, financial read access, and order/subscription management. It has no
account-wide, administrator, release, or store-editing permissions. The Google
Play Android Developer API is enabled in the existing Cloud project.

## Build controls

The ordinary candidate profile keeps all public launch-containment switches
false. The explicit `billing_test=true` candidate input adds:

- `CHRONOSPARK_INTERNAL_BILLING_TEST=true`.
- A private verified account cohort matching the reviewed assistant-policy
  cohort, compiled as `CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS`.
- Real Google Play purchasing and receipt verification for authenticated cohort
  members on production Android/cloud builds only.
- A mandatory Google-verified test purchase marker in both request and response.

The same compiled Dart flag selects a release manifest overlay that restores
`com.android.vending.BILLING`. Ordinary contained builds continue to remove it.
Local, non-release, invalid and conflicting native billing definitions are
rejected. The candidate gate checks the final merged bundle manifest: billing
permission must be present exactly when the internal billing profile is selected.

Missing, malformed or mismatched cohorts, local mode, non-Android platforms and
billing bypasses fail closed. Account changes rebuild the repository and its
use cases. No license test grants an automatic premium entitlement.

The internal paywall explicitly identifies subscription testing, asks for a
Google test payment method and states that AI and credit spending are unavailable.
It does not advertise an AI-credit benefit or a usable wallet in this profile.

The candidate requires a reviewed full source SHA, successful exact-source CI,
the effective private policy SHA256 and the explicit billing profile. Before
signing, `verify_internal_billing_backend.mjs` checks the live verifier guard,
matching normalized Google credentials in GitHub and the deployed verifier,
both approved Play base plans/prices and the matching backend catalog. RTDN must
reject an unauthenticated request and have a successfully processed Google Play
test notification within the last 24 hours. Send a fresh Console test if that
evidence has expired. The billing identity does not need Pub/Sub infrastructure
permissions. The report contains no credentials or purchase tokens; these checks
do not establish purchase or renewal behavior.

The candidate workflow can run the same read-only checks with
`billing_test=true` and `preflight_only=true`, from the existing approved tooling
branch `fix/app-only-readiness-priority2-20260902`. The source SHA remains explicit.
GitHub's production environment does not permit the repair branch; its protection
rules are preserved. CI and policy-hash inputs are mandatory for an actual build,
and unused only in this read-only preflight. No AAB, Play upload, purchase or
production rollout is part of that check.

## Remaining device evidence after an authorized build

Update through the existing internal-testing track to preserve the Moto's local
data. Confirm package, version code, signed-in app account, purchasing Google
account and a Google test payment method before the first purchase.

Exercise monthly and annual purchase success, decline, pending/cancelled flow,
acknowledgement, restore, relaunch, account isolation, accelerated renewal,
cancellation through expiry, grace, hold and recovery. Correlate each transition
with server entitlement and RTDN records; repeated events must not duplicate
grants. AI credit spending and paid AI readiness are separate blocked gates.

Host tests and the processed test RTDN do not establish this lifecycle evidence.
