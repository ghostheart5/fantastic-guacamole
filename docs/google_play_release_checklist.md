# ChronoSpark Google Play Release Checklist

Quick release gate audit: [GOOGLE_PLAY_READINESS_AUDIT.md](GOOGLE_PLAY_READINESS_AUDIT.md)

## Current candidate - 2026-09-04

Use the [signed-candidate/device checkpoint](engineering/SAFE_QUICK_PHASE_5_6_STATUS_20260904.md)
and [backend checkpoint](engineering/SAFE_QUICK_PHASE_7_STATUS_20260904.md) for
current evidence. Frozen app source `61c7331dda9e82201a0561dbcd79aa0b37118446`
passed CI `33939436515` (2,352 Flutter tests, 15 configuration tests, static,
golden, integration and coverage gates). Signed build `33940078212`, focused
physical smoke and one task lifecycle passed. Full UAT and release approval are
still open. Changed source requires its own final evidence; this checklist does
not authorize upload, publishing, credential replacement or feature enablement.

## Firebase and Supabase authentication

- [x] FlutterFire project configured for `chronospark-app`
- [x] Production Android project/app identity matches the frozen candidate, as recorded in the backend checkpoint
- [x] Android `google-services.json` generated
- [ ] Verify API-key consumer mappings/restrictions and applicable App Check readiness without breaking approved clients
- [ ] Verify real Messaging delivery and any separately approved telemetry/alert journey; saved email preferences are not delivery proof
- [ ] Verify Supabase Email/Password and Google OAuth signup/sign-in/recovery/deletion behavior on the final candidate

Account authentication is implemented with Supabase, not Firebase Auth. Do not
enable Firebase Email/Password to satisfy this checklist. Apple configuration
is outside this Android Play gate. Keep disabled telemetry and external features
disabled until their independent exit gates and enablement approval are complete.

## In-App Purchases

Billing is contained off in the current candidate. Source presence is not live
purchase/entitlement proof, and no paid benefit may be advertised as available.

- [x] Product IDs in code:
  - `chronospark_premium_monthly`
  - `chronospark_premium_annual`
- [x] Client-side receipt verification hook added
- [x] Server authority source exists in `supabase/functions/verify-receipt`; the retained local stub is not production proof or a release endpoint
- [x] Purchase/restore source exists but is disabled by launch containment
- [ ] Reconcile current Console products, IDs, status and approved pricing before any separately authorized product changes
- [ ] Complete backend recheck-token/worker and RTDN authority gates before enabling billing
- [ ] Prove the full purchase/restore/refund/revocation/account-change lifecycle with authorized license-test accounts, not a verifier stub

## Android Compliance

- [x] INTERNET permission in `AndroidManifest.xml`
- [x] BILLING and advertising-ID permissions explicitly removed for the contained candidate
- [x] Gradle does not pin Billing 6; `in_app_purchase_android` owns its dependency
- [x] Release signing scaffold in `android/app/build.gradle.kts`
- [x] `android/key.properties.example` added
- [x] Existing protected upload signing produced the verified AAB; do not recreate or replace the keystore
- [ ] Reconcile upload certificate and Play App Signing authority separately; never commit passwords or keystores
- [ ] Confirm final resolved dependency/permission manifest and native-symbol completeness; retain 16 KB runtime evidence separately from bundle alignment

## Policy and Legal

- [x] Privacy policy file at `assets/legal/privacy_policy.html`
- [x] Terms of service file at `assets/legal/terms_of_service.html`
- [x] Support page file added at `web/support/index.html`
- [ ] Verify final public privacy, terms, support and deletion services over valid HTTPS with canonical-content parity; source files and HTTP 200 are insufficient
- [ ] Save and read back the verified privacy and account-deletion URLs in Play Console
- [ ] Set and verify target audience **18+ only**, matching approved bundled policy
- [ ] Obtain owner/qualified decisions on legal operator, jurisdiction, retention, deletion commitments and policy acceptance records
- [ ] Complete Spanish legal/usability/distress-language human review; source currently supports both English and Spanish
- [ ] Add Play Console microphone disclosure: optional voice-to-text for Smart Planner and SI Console, only after user taps voice controls
- [ ] Confirm Play Console developer support email/contact is configured

Domain/DNS/certificate work remains separately deferred and is excluded from the
current closeout repair scope. That exclusion does not mark public-service or
policy obligations complete.

## Versioning and Release

- [x] Gradle release override support for app id and versioning added
- [x] Verified signed AAB `4.1.0+2026083003`, target API 36, from frozen source above; full hash/provenance retained in checkpoint
- [ ] Confirm final version code exceeds the actual highest uploaded Play version, without inventing a new value
- [ ] Build a replacement candidate only when final source/configuration changes require it; preserve existing signing and release containment
- [ ] After explicit upload approval, upload the identified AAB to the owner-approved test track and verify Play-delivered installation/pre-launch results

## Testing

- [x] Exact-source CI static, Flutter, configuration, golden, integration and 71.7% coverage gates passed for the frozen candidate
- [x] Focused signed-candidate physical smoke and one task save/restart/complete/restart journey passed
- [ ] Complete the remaining physical-device scenarios in `testing/CHRONOSPARK_UAT_MATRIX.md`, including accessibility, interruption, offline and performance gaps
- [ ] Execute remaining release-critical Maestro journeys against the final signed candidate; do not substitute emulator/QA artifact evidence
- [ ] Complete five real moderated Priority 6 participant sessions and deferred qualified human/safety/language review

Use focused reruns for repairs. Do not rerun a passing full suite on unchanged
source because an older checklist was stale; run the required final CI once the
changed source is frozen.

## Closed Testing Notes

- QA/tester bypass builds are separate diagnostic artifacts, not production
  readiness evidence. Use production authentication/containment settings for
  the release candidate; do not expose unfinished flows or bypass account gates.
- [ ] Recheck current Console eligibility before deciding whether additional
  closed testing is required; historical completion is preserved in the
  production-access draft, not assumed current or restarted automatically
- [ ] Obtain real recruitment, engagement, feedback, intended track/countries
  and production-access answers from the owner before saving/submitting
