# Monetization Verify Deployment Review

## Local Evidence

1. Function folder exists: `supabase/functions/monetization-verify`.
2. Expected route: `POST /functions/v1/monetization-verify`.
3. Expected staging base URL: `https://pxtjkwfedrtnxuihtdox.supabase.co`.
4. Expected auth mode: JWT verification enabled by local Supabase config, with a bearer-authenticated caller verified through Supabase Auth.
5. Local client construction resolves `/functions/v1/monetization-verify` from an HTTPS Supabase URL.

## Required Environment Variables

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY` or `SUPABASE_ANON_KEY`
- `SUPABASE_SECRET_KEY` or legacy `SUPABASE_SERVICE_ROLE_KEY`, server-side only
- `GOOGLE_SERVICE_ACCOUNT_JSON`, server-side only
- `ANDROID_PACKAGE_NAME`
- `ALLOWED_ORIGINS`

## Required Secrets

- Server-side Supabase privileged key.
- Google service-account JSON.

No values are recorded here, and neither secret may appear in client code or test scripts.

## Deployment Workflow Evidence

- Local Supabase configuration includes `monetization-verify` with JWT verification enabled.
- The repository includes client deployment workflows, but no `supabase functions deploy` command or Edge Function CI/CD deployment step was found.

## Deployment Evidence Status

**MISSING FOR STAGING.** Local source and configuration evidence exist, but staging deployment, route availability, deployed version, and deployed secret configuration are not proven locally.

## Remaining Unknowns

- Whether `monetization-verify` is deployed to staging.
- Whether the expected staging route responds as configured.
- Whether deployed JWT enforcement matches local config.
- Whether required server-side variables and secrets are configured in staging.
- Whether the deployed version matches local source.
- Whether the route is isolated from production.

Production release remains **NO**.