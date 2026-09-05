# Data safety correction gate

Do not save the Data safety form until every answer is reconciled against the exact signed release artifact, dependency lockfile, manifest, runtime network behavior, Supabase schema, Firebase services, and deletion implementation.

This is an unsaved correction draft. Console descriptions and broken-link
observations originate in the [2026-08-31 readback](console-readback-2026-08-31.md),
not a new inspection. Use the [current signed-candidate checkpoint](../../docs/engineering/SAFE_QUICK_PHASE_5_6_STATUS_20260904.md)
and [backend checkpoint](../../docs/engineering/SAFE_QUICK_PHASE_7_STATUS_20260904.md)
without promoting their partial proof to complete runtime/Data Safety evidence.
Domain repair is excluded from the current closeout scope; working public
privacy/deletion services and matching declarations remain release gates.

## Confirmed corrections

1. Verify the approved public privacy URL (`https://chronospark.app/privacy/`)
   serves the final policy over valid HTTPS before saving it in Console. Do not
   substitute the old GitHub Pages URL without checking its redirect and content.
2. Verify the approved account-deletion URL
   (`https://chronospark.app/delete-account/`) exposes a working external request
   route over valid HTTPS before saving it. A loaded page is not deletion proof.
3. Select OAuth as an account-creation method because the app supports Google sign-in.
4. Do not keep the optional partial-data-deletion answer as `Yes` unless a separate working external request path and matching in-app behavior are verified. The current GitHub URL is broken and is not a valid deletion service.

## Exact-artifact verification required

The historical Console summary said five data types were collected or shared,
and invalid URLs prevented progression to the Data types and handling review.
Recheck the current form and verify at minimum:

- email address;
- user ID;
- user-generated planning content;
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
- a disabled telemetry or paid feature becomes reachable in the candidate.
