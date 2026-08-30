# Production Backend Release Gate

The tagged Android release is fail-closed until the same checked-out commit has
passed both the reusable application quality gate and its required disposable
Supabase database gate, followed by linked production migration inventory,
deployed Edge Function and secret-name checks,
live endpoint contracts, App Links, Google Play catalog, and RTDN configuration.
The workflow builds and publishes one run-scoped AAB; it does not rebuild after
the backend evidence is captured.

## Deployment Order

1. In a disposable fresh project, review and pass every tracked migration through
   `20260830152232_harden_phase8_billing_authority.sql`, both billing pgTAP
   contracts, and database lint. Only after that independent evidence and a
   separately approved production change plan may the same migrations be
   applied to the production project.
   Do not run the Android release while linked migration inventory differs from
   the repository.
2. Set the required Edge Function secrets without committing their values:
   `ANTHROPIC_API_KEY`, `GOOGLE_SERVICE_ACCOUNT_JSON`,
   `ANDROID_PACKAGE_NAME`, `RTDN_AUDIENCE`,
   `RTDN_SERVICE_ACCOUNT_EMAIL`, and `ACCOUNT_DELETE_RECONCILE_SECRET`.
3. Deploy `ai-proxy`, `ai-report`, `planner-explanation`, `verify-receipt`,
   `google-play-rtdn`, `account-delete`, and `account-delete-reconcile` from the exact release
   commit. `account-delete-reconcile` and `google-play-rtdn` use their own
   fail-closed authentication and therefore have platform JWT verification
   disabled in `supabase/config.toml`.
4. Configure Google Play RTDN to publish to the production Pub/Sub topic.
   Configure its push subscription to call
   `<SUPABASE_URL>/functions/v1/google-play-rtdn` with OIDC enabled. The audience
   and service-account email must match the Edge secrets.
5. Publish `https://chronospark.app/.well-known/assetlinks.json` with the exact
   production package and signing-certificate SHA-256 fingerprint.
6. Enable the scheduled `Backend Reconciliation` workflow. Its protected
   production secret must match the Edge `ACCOUNT_DELETE_RECONCILE_SECRET`.
7. Send the Play Console test notification and retain proof that the matching
   RTDN message reached the production function before rollout.
8. Deploy and verify the provider-recheck worker. The queue stores only hashed
   purchase-token identifiers, so the worker must use an approved mechanism to
   reacquire a usable token before querying Google Play; it must not mark work
   complete without authoritative reconciliation.

## GitHub Production Secrets

The protected `production` environment must provide:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_REF`
- `SUPABASE_DB_PASSWORD`
- `CHRONOSPARK_SUPABASE_URL`
- `CHRONOSPARK_SUPABASE_ANON_KEY`
- `SUPABASE_SECRET_KEY`
- `CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT`
- `CHRONOSPARK_AI_PROXY_ENDPOINT`
- `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT`
- `CHRONOSPARK_ANDROID_SHA256_CERT`
- `GOOGLE_SERVICE_ACCOUNT_JSON`
- `RTDN_PUBSUB_SUBSCRIPTION`
- `RTDN_AUDIENCE`
- `RTDN_SERVICE_ACCOUNT_EMAIL`
- `ACCOUNT_DELETE_RECONCILE_SECRET`
- Android signing and Firebase configuration secrets already required by
  `.github/workflows/android-release.yml`

The Google service account needs the least Android Publisher permissions needed
to read subscription authority and acknowledge verified purchases, plus permission
to read the configured Pub/Sub subscription. The production backend check reads
configuration and catalog state only. The scheduled reconciler processes only
deletion requests that were previously authenticated and persisted by the
account owner.

## Account Deletion Recovery

`account-delete` accepts the existing authenticated empty JSON request after a
recent sign-in, derives opaque request credentials server-side, and leases a
durable deletion record. It records session revocation, storage cleanup, Auth
deletion, and completion independently. `{ "action": "status" }` reads the
durable state for the same authenticated request without advancing it.

`account-delete-reconcile` resumes expired leases on a schedule. A durable
completion tombstone remains after Auth deletion because a signed JWT can
outlive its Auth session. The sync-bucket insert and update policies consult
that tombstone and reject attempts to recreate cloud data after deletion starts.

## Release Evidence

Each release run retains:

- exact source commit and tag provenance;
- linked local and production migration inventory;
- deployed function inventory and required secret names, never secret values;
- live Supabase endpoint, App Links, Pub/Sub, and Play catalog results;
- signed AAB SHA-256 and signing-certificate evidence.

These gates do not replace signed-device purchase, renewal, cancellation,
refund, restore, account deletion, process-death, or RTDN delivery testing.
Those runtime scenarios, including subscriptions-center re-subscription and
detached-account recreation, must be completed separately before production
rollout.
