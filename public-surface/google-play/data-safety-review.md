# Data safety correction gate

## October 2, 2026: build 3102 reconciliation draft

Scope: intended public-profile candidate `4.2.3+2026083102`, package `com.ghostheart5.chronospark`, including the local paid-reply recovery repair. This is preparation for review against the final source, configuration, signed artifact, and deployed services. It records no current Console answers, saved form, submission, hosted-policy publication, or production cleanup/deployment proof. Conflicting workflow guidance below is historical; use the [current requirement disposition](../../docs/engineering/RELEASE_REQUIREMENTS_20260926.md) and [public capability checkpoint](../../docs/engineering/PUBLIC_CAPABILITY_CHECKPOINT_20260926.md).

### Paid-reply recovery: source behavior to reconcile

The repaired AI proxy may retain the complete generated paid reply in an account-linked server request record so an interrupted request can recover its answer. The reply may reproduce user-supplied planning or personal content. The intended settlement path stores reply content with a 15-minute expiry atomically. Retrying an ambiguous settlement can refresh this window; it is not a maximum duration measured from the original debit. Replay rejects expired, missing, or invalid expiry and requires the current account's request authority. Only an authoritative HTTP 404 with code `PGRST202` identifying a missing TTL-capable settlement RPC permits metadata-only fallback: a fresh reply can still be returned, but later recovery is unavailable for that request. Timeouts and HTTP 5xx responses do not permit that fallback.

Replay expiry is not proof of physical deletion at that instant. The existing database migration defines periodic removal of expired response payloads and a five-minute cleanup schedule. Deployment, enabled job state, successful executions, removal lag, and any backup retention have not been checked for this candidate. Do not promise a precise physical-deletion deadline from the source schedule. Billing and usage metadata, provider retention, and user-submitted response reports have separate purposes and retention rules.

The canonical privacy draft is `web/privacy/index.html`; `legal/legal_documents.json` generates `privacy.html`, `assets/legal/privacy_policy.html`, and `assets/legal/privacy_policy.txt`. The October 2 local disclosure distinguishes temporary server reply recovery from the absence of a user-accessible saved conversation archive. Local consistency does not establish the currently hosted policy or installed app's wording.

### Pending final-candidate checks

| Item | Evidence required before accepting a declaration | Current state |
| --- | --- | --- |
| Candidate identity | Final source SHA, effective public configuration, AAB hash, installed package/version, and deployed AI proxy/RPC definitions match | Pending |
| Collected content | Map questions, selected context, recent messages, generated reply content, identifiers, and reports to the actual transmitted and persisted fields; consider Other user-generated content and Other in-app messages against the real payload | Pending |
| Sensitive content | Determine whether actual off-device emotional or other health-related information requires Health info disclosure; classify payloads separately from the wellness feature declaration | Pending |
| Storage and purpose | Treat the server reply cache as stored data used for app functionality and interrupted-request recovery; do not label it ephemeral merely because replay lasts 15 minutes | Pending |
| Optionality and processors | Verify user controls and the provider/data/cost confirmation; review Supabase and Anthropic processing and any applicable sharing exclusions against current terms and behavior | Pending |
| Retention and cleanup | Verify atomic expiry, expiry rejection, account/request isolation, missing-RPC fallback, current cleanup definition/job and successful removal of a disposable expired reply; record delays and backup limitations | Pending |
| Deletion | Verify the exact account-deletion path removes or appropriately handles cached content and related records; retain the separate billing/security retention explanation | Pending |
| Disclosure parity | Compare the final in-app policy, current hosted canonical policy, EN/ES notices, and all active distributed versions; reconcile the saved Console form only after authorized readback | Pending |

Google defines ephemeral processing as memory-only handling for the real-time request. Persistent retry storage does not meet that description; a short lifetime alone is insufficient. Collection, purposes, optionality, and sharing must be assessed independently. Reference checked October 2, 2026: [Google Play Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).

The exact category selections and final Console state remain unverified. No checklist row is an approval or a claim that deployment, deletion, or runtime validation has occurred.

## Historical review records

## September 12 current readback

The [3032 blocker closeout](../../docs/engineering/BLOCKER_CLOSEOUT_3032_20260912.md)
records the current eight-type Console preview and its handling answers. These
are not a new submission or public declaration. The exact missing public privacy
paragraph is prepared in [draft PR 103](https://github.com/ghostheart5/fantastic-guacamole/pull/103).
Voice provider identity is verified on the Moto; actual dictation and final
provider-handling/disclosure review remain open. The prior public-page hold has
not been lifted. Historical items below retain their original evidence limits.

Do not save the Data safety form until every answer is reconciled against the exact signed release artifact, dependency lockfile, manifest, runtime network behavior, Supabase schema, Firebase services, and deletion implementation.

This is an unsaved correction draft. Console descriptions and broken-link
observations originate in the [2026-08-31 readback](console-readback-2026-08-31.md),
not a new inspection. Use the [historical September 4 signed-candidate checkpoint](../../docs/engineering/SAFE_QUICK_PHASE_5_6_STATUS_20260904.md)
and [historical September 4 backend checkpoint](../../docs/engineering/SAFE_QUICK_PHASE_7_STATUS_20260904.md)
without promoting their partial proof to complete runtime/Data Safety evidence.
Domain repair was excluded from that September 4 closeout scope; working public
privacy/deletion services and matching declarations remain release gates.

## September 9 private-testing disclosure correction

The canonical privacy, terms, support, and deletion sources now distinguish the contained public configuration from eligible private internal-testing builds. Generated in-app copies match those sources. These are local prepared changes; publishing the pages and independently reading them back are still required. The historical URL failures below are not current URL or Console evidence.

When the exact build enables the private cohort, review Google Play subscription and credit-top-up purchase verification, wallet/credit usage, reservation/settlement and retry metadata. Review the actual external AI payload: the internal credit test sends only a fixed fictional prompt, while a separately gated Planner explanation can send selected visible plan clauses and planning evidence after the provider/data/cost confirmation. Anthropic is the disclosed provider. The optional explanation service can retain response content for its disclosed short replay window; usage/billing metadata persists separately. Account, wallet and AI service operations must not be mistaken for disabled cloud planning sync or restore.

License-tester status and test payment methods govern whether a test purchase is free; internal-track enrollment alone does not. This change does not attest current Console enrollment, product setup, submitted declarations, or exact-artifact runtime traffic. Follow [Google's billing-testing guidance](https://developer.android.com/google/play/billing/test) and inspect the enabled feature set before completing the form.

## Historical correction items requiring current verification

1. Verify the approved public privacy URL (`https://chronospark.app/privacy/`)
   serves the final policy over valid HTTPS before saving it in Console. Do not
   substitute the old GitHub Pages URL without checking its redirect and content.
2. Verify the approved account-deletion URL
   (`https://chronospark.app/delete-account/`) exposes a working external request
   route over valid HTTPS before saving it. A loaded page is not deletion proof.
3. Select OAuth as an account-creation method because the app supports Google sign-in.
4. Do not keep the optional partial-data-deletion answer as `Yes` unless a separate working external request path and matching in-app behavior are verified. The August 31 readback found a broken GitHub URL; verify the current request service before making this declaration.

## Exact-artifact verification required

The September 9 voice repair adds an explicit English/Spanish speech-provider disclosure before both Smart Planner and SI Console dictation, including users who previously granted microphone permission. Cloud-mode device dictation may send audio to the selected speech provider for transcription under that provider's policies; it is not guaranteed to remain on the device. ChronoSpark does not store audio recordings, and transcripts require a separate user action to send or save. Review optional audio/voice data, the actual provider, processing location, retention and Play's collection/sharing definitions against the signed artifact and a speech-capable device. This path is separate from AI-credit spending and is disabled in the local QA configuration. Local policy copies are prepared; public publication remains explicitly held by the owner.

The historical Console summary said five data types were collected or shared,
and invalid URLs prevented progression to the Data types and handling review.
Recheck the current form and verify at minimum:

- email address;
- user ID;
- user-generated planning content;
- optional voice/audio processing by the device speech-recognition provider and the resulting user-reviewed transcript;
- app interactions or activity;
- device or other identifiers, including push-token handling;
- whether any data is shared under Play's definition or only processed by contracted service providers;
- collection purpose, optionality, ephemerality, retention, and deletion for every selected type;
- Firebase Messaging and installation/device-token behavior; the app's account
  authentication uses Supabase, not Firebase Authentication. Do not enable a
  Firebase Auth provider merely to satisfy this checklist;
- Supabase Authentication, database, Edge Function, and storage behavior;
- Google sign-in behavior;
- analytics and Crashlytics remain disabled in the exact artifact.

## Current declarations that appear consistent but still require exact-artifact proof

- data encrypted in transit;
- no Advertising ID use;
- no ads;
- no health features;
- no financial features;
- not a government app;
- restricted functionality requires sign-in;
- target age **18+ only**, matching the approved bundled privacy policy and terms;
  correct the historical 16-17 selection before submission and verify persistence.

## Stop conditions

Stop and do not submit if:

- any declared URL is not publicly reachable without authentication;
- the exact artifact transmits a data type not selected in the form;
- the privacy policy and Data safety answers disagree;
- reviewer sign-in instructions are stale;
- account deletion does not delete the account and associated data as described;
- a telemetry or paid feature becomes reachable outside its documented build/account eligibility, or its actual data processing is absent from the policy and declarations.
