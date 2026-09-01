# Data safety correction gate

Do not save the Data safety form until every answer is reconciled against the exact signed release artifact, dependency lockfile, manifest, runtime network behavior, Supabase schema, Firebase services, and deletion implementation.

## Confirmed corrections

1. Replace the broken privacy URL with `https://ghostheart5.github.io/fantastic-guacamole/privacy/` after the new public site is live.
2. Replace the broken account-deletion URL with `https://ghostheart5.github.io/fantastic-guacamole/delete-account/` after the new public site is live.
3. Select OAuth as an account-creation method because the app supports Google sign-in.
4. Do not keep the optional partial-data-deletion answer as `Yes` unless a separate working external request path and matching in-app behavior are verified. The current GitHub URL is broken and is not a valid deletion service.

## Exact-artifact verification required

The current Console summary says five data types are collected or shared, but the invalid URLs prevent progression to the Data types and handling review. Verify at minimum:

- email address;
- user ID;
- user-generated planning content;
- app interactions or activity;
- device or other identifiers, including push-token handling;
- whether any data is shared under Play's definition or only processed by contracted service providers;
- collection purpose, optionality, ephemerality, retention, and deletion for every selected type;
- Firebase Authentication and Messaging behavior;
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
- target age 16-17 and 18+.

## Stop conditions

Stop and do not submit if:

- any declared URL is not publicly reachable without authentication;
- the exact artifact transmits a data type not selected in the form;
- the privacy policy and Data safety answers disagree;
- reviewer sign-in instructions are stale;
- account deletion does not delete the account and associated data as described;
- a disabled telemetry or paid feature becomes reachable in the candidate.
