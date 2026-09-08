# Billing review and provider failure completion

Status: completed. Live refund-review response, provider-failure/refund acceptance, post-deployment normal spending, and the final hosted database gate passed.

## Changes and release identity

- Refund review implementation: `8012e72775dcf1e077ebcf31be448fe44c0ff085`.
- Provider timeout repair: `dfe168010e4160c435014fa53525c4da2d5fa629`.
- Deployed `google-play-rtdn` v18 and `ai-proxy` v14; every deployed source file matches the corresponding local source after newline normalization. Google OIDC authentication and AI JWT authentication remain enabled as before.
- The Moto remains on the Play-installed `4.1.0+2026083018`. These are backend changes; no AAB rebuild, reinstall, database schema change, or production-track publication was needed.

## Pending refund reviews

The authenticated RTDN handler now recognizes `pendingRefundReviewNotification` and calls Google's `orders.reviewrefund` API. It sends `NEUTRAL`, leaving the refund decision to Google, and records success only after a successful API response. The required sample/information flag is true because the paywall explains functionality before purchase.

The handler omits optional usage percentages and consumption events: the current allowance ledger cannot reliably attribute all consumption to one order. It does not send account identifiers, prompts, profile context, location, or unrelated activity. It does not grant/revoke entitlement or debit/refund the wallet in response to a review request. Actual subscription/voided authority continues to govern access.

Validation covers malformed tokens and orders, unknown reasons, response minimization, HTTP 400/401/403/429/500/503, and idempotent success. Failed responses remain visible and retryable. Existing Pub/Sub claims suppress already completed message deliveries; Google records the first response for a review token and accepts duplicate responses.

Live acceptance used the owner's free `Test card, approves then charges back` instrument on the Moto. The checkout explicitly stated no charge. Google delivered a review at `2026-09-08 07:11:25.153037Z`; the handler recorded `processed`, `reviewResponse: accepted`, `refundPreference: NEUTRAL`, and no failure at `07:11:25.420Z`. This replaces the earlier unsupported/ignored behavior. The test plan later expired normally and removed paid access; acceptance of a neutral review response does not itself prove Google approved a refund.

Official references: [review API](https://developers.google.com/android-publisher/api-ref/rest/v3/orders/reviewrefund?hl=en), [chargeback review guidance](https://developer.android.com/google/play/billing/provide-refund-and-chargeback-suggestions), [license test instrument](https://developer.android.com/google/play/billing/test#test-user-initiated-chargebacks).

## Provider failures and exact refunds

The actual AI request handler was invoked in an isolated local process with live Supabase authentication and live reserve/settle routines for the authorized second account. Its synthetic prompt contained no saved personal context. No shared credential or live service configuration was changed for fault injection.

| Failure | Transport evidence | Result |
|---|---|---|
| Provider rejection | Real Anthropic HTTP 401, deliberately invalid key only in the diagnostic process | API 502; one reservation refunded; retry 409 with no second provider call |
| Service unavailable | Controlled HTTP 503 response at the provider boundary | API 502; exactly one refund; replay makes no debit |
| Network failure | Controlled rejected provider transport | API 500; exactly one refund; replay makes no debit |
| Stalled provider | Transport held open until the handler's real 25-second abort fired | `provider_timeout`; exactly one refund; replay makes no debit |

The second-account balance was 19 before and after every diagnostic. Four durable request rows show `refunded`; no reservation remains unresolved. Temporary diagnostic login sessions were signed out locally and no credentials were written to disk. These are real ledger mutations with controlled fault injection; they are not a claim that Anthropic experienced a natural infrastructure outage or that the injected cases traversed the deployed gateway.

The production handler now supplies a 25-second upstream deadline so it can attempt settlement before an edge request expires. The new host tests exercise the actual served handler for provider 401/429/500/503, network failure, timeout, malformed JSON, and empty output, verifying reservation-before-provider, one refund, and no repeated debit/provider call.

After deployment, the Moto successfully called `ai-proxy` v14 with its normal credential: one synthetic reply changed the owner balance from 20 to 19; retry reported already completed with no second charge. External-AI consent was restored off. Both accounts finish with 19 free credits and zero unresolved reservations. The owner's profile remains level 2 / 200 XP / 2-day streak.

## Validation and evidence

- Final local Edge Function gate: formatting, lint, seven entrypoint type checks, and 121 tests across 14 files passed with zero failures, errors, or skips.
- Hosted database gate `34197720105` passed on the refund-review commit, including 120 Edge Function tests and the database suite.
- Final timeout-source hosted gate: [34198405811](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34198405811) passed on the exact source: 121 Edge Function tests, 341 pgTAP assertions across nine files, schema lint, and replay policy for 47 migrations. The JUnit report has zero failures, errors, or skips.
- Final live readback: five billing events processed, zero failed or processing; four second-account diagnostic requests refunded, zero open reservations; normal owner spending completed once. Both wallets are free 19, both external-AI consent switches are off, and the phone is back on the owner Nexus at level 2 / 200 XP.
- Local detailed evidence: `test-results/refund-review-20260908/`; Moto captures: `test-results/moto-3018-validation/refund-*` and `timeout-deploy-*`.
- Earlier exact-AAB smoke, integration, and eleven Maestro journeys remain documented in [3018 validation](INTERNAL_3018_FINAL_VALIDATION_20260908.md). They were not rerun for a backend-only change; focused deployed acceptance and backend regressions were run instead.

No monkey or level-20 testing was run. No progression was accumulated. All earlier artifacts and unrelated untracked work were preserved.
