# Qualified review packet - build 3032

**Prepared for qualified review; not a signed approval.** September 12, 2026.

## Exact target

- App: ChronoSpark 4.1.0+2026083032, package com.ghostheart5.chronospark.
- App source: 91d9086ea76ecb10de74e950be3dabfa964e4043.
- Signed candidate run: 34659446880.
- AAB SHA-256: e266e0795edcb04a298d706fd2f7e4027ff8055cbbdc9c93ea656b4974454b49.
- Distribution: existing Google Play internal-testing track; installed on the Moto.
- Public subscriptions, external AI and credit spending remain contained. The
  approved private test cohort can use its enabled test features. No ads in any tier.
- This packet supersedes the review target in the older ignored 3027 packet.

## Material to examine


- Voluntary context and revocation: `lib/state/providers/consented_human_context_provider.dart`, corresponding provider tests, and `PRIVACY_SAFETY_DATA_MAP.md`.
- Routing and uncertainty: `lib/domain/policies/emotional_safety_policy.dart` and its tests. Review direct distress, indirect language, negation, adversarial spelling, false positives and missed cases.
- Visible support: `lib/ui/system/crisis_dialog.dart` and its tests. Verify locale/region behavior, unknown-region fallback, failed external actions, dismissibility and explicit gentle continuation.
- Planning/SI boundaries: `lib/domain/policies/assistant_safety_policy.dart`, Smart Planner query controller and SI V2 provider. Examine crisis pressure, gamification, diagnosis/treatment claims, contradictory evidence and advice beyond app evidence.
- Authority: `test/domain/policies/assistant_safety_policy_test.dart` and `test/state/providers/si_v2_safety_service_test.dart`. Verify read-only SI, proposal-only planning and separate explicit Creator confirmation on a real device.
- External provider: deployed `ai-proxy` version17, optional Planner explanation, consent screens, exact disclosed data categories, actual organization retention settings and refund/cancellation behavior. Public activation is not authorized by a generic provider policy page.
- User-facing claims: current privacy policy, store description, onboarding and paywall. The product is a planning/reflection tool, and never shows ads. Review the accuracy and comprehensibility of those claims.

## Required record

Record reviewer identity and relevant qualification, date, exact candidate/configuration, languages/regions examined, method, concrete observations, limitations, defects by severity, retest results and explicit disposition. Keep personal credentials and raw private user histories out of the record. An unsigned testing-provider template is not a qualified safety review.

## Reviewer access

The designated store-review account's current authority was independently read
on September 12 at 08:12:39 UTC: confirmed, nonanonymous, active `review_access`,
no automatic renewal, 300 credits, expiry October 11 at 12:39:48 UTC. This is a
complimentary account-bound grant, not a fabricated Google purchase or admin role.
Credentials remain in the private Play Console app-access record.

The isolated Moto Android user 11 has reached Google services Terms of Service.
The owner must review and complete that setup; no agreement is accepted on their
behalf. Main Android user 0 and its data are preserved. Full reviewer-device
sign-in, core creation/edit/completion, SI, Planner, Creator, enabled restricted
features, restart and sign-out remain pending. Provisioning does not prove access.

## Engineering evidence to review

- [Exact 3032 artifact and hosted results](FINAL_3032_RELEASE_VALIDATION_20260911.md):
  canonical Flutter 2919; QA 15; Windows goldens 48; launcher 17; Linux integration
  8; SQL 350 across 13 files; Edge Functions 142; independent Windows 2922 plus 15;
  native 15/15 across five hosts; strict actual-bundle 16 KB; 11 Maestro journeys;
  final disposable-emulator Monkey 5 variants/1700 events. Failed attempts retained.
- [Installed 3032 device results](INSTALLED_3032_VALIDATION_20260912.md): six SI
  cases; four Energy/Clarity combinations; four Momentum horizons; 100 targeted
  navigation actions; nine emotion states; Planner response/evidence controls;
  real 3-credit request, zero extra retry charge, consent withdrawal; restart with
  level 20, 36212 XP and 1448 completions intact. Filtered runtime scan found zero
  matching fatal/app-ANR/unhandled/overflow markers.
- These are bounded agent and automated tests, not independent participant UAT or
  qualified privacy/legal/clinical judgments. They do not approve every future
  public configuration, device, region, provider change or input.

## Disclosure and configuration decisions

The Anthropic organization uses default 30-day retention, no Zero Data Retention,
global processing and disabled optional feedback sharing, as recorded in the
private provider evidence. Provider exceptions remain disclosed. The signed app
contains this paragraph; public privacy parity is prepared in
[PR 103](https://github.com/ghostheart5/fantastic-guacamole/pull/103), not yet published.

Play Console's current preview has eight data types: Name, Email address, User IDs,
Purchase history, Photos, Voice or sound recordings, App interactions, and Device
or other IDs. It lists no sharing, encrypted transit, account deletion, and no
separate partial-data deletion request. Review the applicability of provider and
user-initiated sharing exclusions, voice processing, retention, optionality, and
any proposed additional external planning payload. Preview is not public readback.

## Required disposition (to be completed by the qualified reviewer)

- Reviewer name, relevant qualifications and scope:
- Review date and exact artifact/configuration:
- Languages, regions, data processors and scenarios examined:
- Method and evidence examined:
- Findings, severity and required repairs:
- Retest evidence and unresolved limitations:
- Explicit approve / approve with conditions / reject disposition:
- Signature and date:

No signature or qualification is supplied by this packet. The two qualified
review dispositions are existing project requirements in EXTERNAL_GATES.md,
not a universal Google certification. No public feature switch is enabled by
preparing this document. Production publication remains prohibited.
