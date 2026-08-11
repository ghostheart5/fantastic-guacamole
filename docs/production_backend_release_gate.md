# Production Backend Release Gate

The Android release workflow is fail-closed until the production backend and
Google Play configuration pass the `production-backend-gate` job.

## Deployment Order

1. Apply all tracked migrations through
   `20260811155019_production_backend_hardening.sql` to the production project.
2. Set these Edge Function secrets without committing their values:
   `ANTHROPIC_API_KEY`, `GOOGLE_SERVICE_ACCOUNT_JSON`,
   `ANDROID_PACKAGE_NAME`, `RTDN_AUDIENCE`,
   `RTDN_SERVICE_ACCOUNT_EMAIL`, and `ACCOUNT_DELETE_RECONCILE_SECRET`.
3. Deploy `ai-proxy`, `monetization-verify`, `google-play-rtdn`,
   `account-delete`, `account-delete-reconcile`, and the three retired endpoint
   tombstones: `delete-account`, `verify-receipt`, and `webhook-ingest`.
4. Configure Google Play RTDN to publish to the production Pub/Sub topic.
   Configure its push subscription to call
   `<SUPABASE_URL>/functions/v1/google-play-rtdn` with OIDC enabled. The OIDC
   audience and service-account email must match the Edge secrets.
5. Send the Play Console test notification. Release is blocked until the
   matching Pub/Sub message is recorded as `processed` in
   `google_play_rtdn_events`.
6. Enable the scheduled `Backend Reconciliation` workflow. Its production
   environment secret must match the Edge `ACCOUNT_DELETE_RECONCILE_SECRET`.

## GitHub Production Secrets

The `production` environment must provide:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_REF`
- `SUPABASE_DB_PASSWORD`
- `CHRONOSPARK_SUPABASE_URL`
- `SUPABASE_SECRET_KEY`
- `GOOGLE_SERVICE_ACCOUNT_JSON`
- `RTDN_PUBSUB_SUBSCRIPTION`
- `RTDN_AUDIENCE`
- `RTDN_SERVICE_ACCOUNT_EMAIL`
- `ACCOUNT_DELETE_RECONCILE_SECRET`

The Google service account needs Android Publisher read access and permission
to read the configured Pub/Sub subscription. The release gate reads catalog
and configuration only; its account-deletion reconciliation call processes
only deletion requests already authorized and persisted by a user.

## Release Evidence

Each release retains:

- linked local/remote migration inventory;
- deployed function inventory and required secret names;
- live Supabase catalog, endpoint-contract, Pub/Sub, and Play product results;
- signed AAB SHA-256 and signing-certificate evidence;
- merged release manifest, permission/exported-component inventory, R8 mapping,
  SDK levels, package name, and version metadata.

Signed-device purchase, renewal, cancel, refund, restore, account deletion,
process-death, and RTDN delivery scenarios remain part of the separate runtime
testing phase and must complete before production rollout.
