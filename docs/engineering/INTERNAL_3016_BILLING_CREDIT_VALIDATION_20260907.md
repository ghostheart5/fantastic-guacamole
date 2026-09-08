# Internal 3016 prepaid and credit validation

## Scope and implementation

Version 4.1.0+2026083016 prepares the two authorized internal license-test accounts for pending prepaid payments and server-authoritative AI credit spending. Public subscription, external-AI, and credit launch switches remain closed. Per-account external-AI consent remains required. No monkey or level-20 testing is authorized in this phase.

- Subscription display and checkout select the exact product/base plan, without falling back to a different plan or introductory offer.
- The internal test profile uses a shared native billing connection with prepaid pending purchases enabled. Pending purchases cannot be acknowledged or grant access. Actual Google purchase-query errors are surfaced even when the plugin wrapper's convenience status reports OK.
- Flutter's pinned Android billing plugin 0.5.2 omits the public reconnect parameter type from its barrel. `google_play_pending_compat.dart` isolates that one private type import. The architecture exception requires the exact file, exact import, and locked plugin version; all other private imports still fail. Remove/review this compatibility exception when upgrading the plugin.
- The internal-only prepaid option requests `chronospark_premium_monthly` / `monthly-prepaid-test`. It remains unavailable until the corresponding Play catalog plan is configured. Planned catalog: one month prepaid, USD 4.99, US. Activate only after the corrected offer selection reaches the testing device.
- Internal AI availability requires the authenticated billing cohort and the same project's canonical HTTPS AI proxy endpoint. The settings disclosure identifies Anthropic, selected context, server credits, and consent. Production credits come from the server wallet; local debit simulation stays disabled in production.
- Deployed AI proxy v13 and all three shared dependencies match local source after line-ending normalization. No backend deployment was made for this change. Live provider credentials and actual credit spending are not yet verified.

## Host checks

The final focused billing/credit run passed all 103 tests. An earlier run exposed one test-harness failure: changing a provider override did not simulate account membership changes. The regression now uses a real Notifier state transition and verifies removal of AI/credit availability after membership revocation. Six native adapter tests pass, including selected-offer/account binding and acknowledgement failure handling. Full exact-source CI and device journeys remain required.

Release/version guards and whitespace checks pass. Targeted Dart analysis of the initial 14 changed/new Dart files reports no issues. The architecture gate initially rejected the plugin's unexported type; after isolating the pinned compatibility exception, the architecture gate passes. Full local analysis was interrupted during a stalled run and is not claimed as passed. Hosted checks are tracked separately.

## Remaining live acceptance

1. Verify the signed new AAB, publish only to the existing internal track, and update Moto through Google Play preserving local data.
2. Verify completed onboarding and both Settings Back controls across owner/second-account/owner switches; verify saved owner data remains intact.
3. Confirm second-account restore cannot claim the owner's active test purchase; returning owner can restore it.
4. Exercise Google's slow approve and slow decline instruments for prepaid: pending state, restart/restore while pending, no premature access/acknowledgement, eventual cancellation or completed purchase, and server entitlement reconciliation.
5. Exercise credit consent-off/local guidance, successful server debit and wallet refresh, insufficient balance, retry/idempotency, failure/refund, and cross-account wallet isolation. Use synthetic test content only.
6. Complete smoke, integration, and journey acceptance on the new source/build. Host mocks and old-build live evidence cannot substitute for these live results.

Status: not yet a full pass. No live pending-payment or credit-spending result is claimed.
