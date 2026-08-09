# Monetization Verify Deployment Evidence

## Local Function Evidence

1. Function folder name: `supabase/functions/monetization-verify`.
2. Expected staging URL: `https://pxtjkwfedrtnxuihtdox.supabase.co/functions/v1/monetization-verify`.
3. Expected method: `POST`.
4. Local Supabase config sets `verify_jwt = true` for `monetization-verify`.
5. Flutter endpoint resolution builds `/functions/v1/monetization-verify` from a configured HTTPS Supabase base URL.

## Deployment Method Evidence

- No local `supabase functions deploy` script or CI workflow deployment step was found.
- The reviewed GitHub workflows deploy client artifacts and inject client Supabase configuration; they do not provide Edge Function deployment evidence.
- The actual staging deployment method is therefore **not evidenced locally** and must be confirmed by the authorized staging operator.

## Required Server-Side Secrets

- `SUPABASE_SECRET_KEY` or legacy `SUPABASE_SERVICE_ROLE_KEY`, Edge runtime only.
- `GOOGLE_SERVICE_ACCOUNT_JSON`, Edge runtime only.

These must never be copied into Flutter clients, client scripts, transcripts, or documentation evidence.

## Required Environment Variables

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY` or `SUPABASE_ANON_KEY`
- `SUPABASE_SECRET_KEY` or `SUPABASE_SERVICE_ROLE_KEY`, server-side only
- `GOOGLE_SERVICE_ACCOUNT_JSON`, server-side only
- `ANDROID_PACKAGE_NAME`
- `ALLOWED_ORIGINS`

## Local Deployment Evidence

- Function source, JWT configuration, environment example, and client route construction exist locally.
- Local source uses server-side Google Android Publisher verification, token binding, and server-side invocation of `apply_verified_purchase`.

## Missing Evidence

- Confirmed staging deployment status and deployment timestamp.
- Confirmed staging route availability at the expected URL.
- Confirmed JWT/auth behavior on the deployed route.
- Confirmed staging environment-variable and secret presence without exposing values.
- Confirmed staging Google Play service-account/API authorization.

Production release remains **NO**.