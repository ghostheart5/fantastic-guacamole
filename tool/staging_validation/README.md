# Ready Backend Staging Checks

> **RETIRED — DO NOT RUN.** ChronoSpark no longer has an approved staging
> Supabase project. Every PowerShell and SQL executable in this directory is
> fail-closed. GhostHeart5 production (`qpwhuckyirnqtmvhpede`) must be changed
> only through reviewed migrations and Edge Function deployments, never by
> retargeting this historical harness. See [RETIRED.md](RETIRED.md).

This directory contains staging-only PowerShell checks for the backend categories marked `READY_FOR_EXACT_TESTS` in [backend_staging_test_harness_plan.md](../../backend_staging_test_harness_plan.md). The runner uses the staging anon/publishable key and authenticated user sessions only. It never accepts, reads, or requires a service-role key.

## Included Checks

- `credit_debit_tests.ps1`: authenticated zero/negative credit debit denial and anonymous debit denial. Valid debit and insufficient-balance assertions are intentionally skipped because no approved wallet setup or cleanup method is available.
- `privileged_rpc_denial_tests.ps1`: normal-user and anonymous denial for `ensure_monetization_wallet(target_user_id)` and `reset_monetization_allowance(target_user_id)`.
- `profile_repair_tests.ps1`: authenticated profile repair, idempotency, caller ownership, and anonymous denial.
- `global_metrics_denial_tests.ps1`: anonymous and normal-user denial for `get_global_metrics()`.
- `rate_limit_rpc_tests.ps1`: anonymous denial, 20 successful calls shared over two sessions for user A, and rejection of request 21.

## Intentionally Not Generated

- Cross-user/core-sync and spoofed-upsert tests: exact minimum seed payloads are not confirmed.
- Storage prefix denial: managed Storage object/API contract is not confirmed.
- Receipt mismatch: confirmed staging Edge Function URL and a staging-safe Google receipt strategy are missing.
- `grant_monetization_credits` denial: the harness plan marks its exact signature as blocked.
- Valid/insufficient credit debit: requires an approved isolated wallet balance setup and cleanup process.

## Required Configuration

Copy `.env.example` to `.env` and supply only staging values. The runner loads `.env` into its own process; process environment variables with the same names are also supported. Do not commit credentials and do not put service-role keys in this directory.

```powershell
$env:STAGING_SUPABASE_URL = 'https://<staging-project-ref>.supabase.co'
$env:STAGING_SUPABASE_ANON_KEY = '<staging-anon-or-publishable-key>'
$env:STAGING_USER_A_EMAIL = '<non-production-email>'
$env:STAGING_USER_A_PASSWORD = '<non-production-password>'
$env:STAGING_USER_B_EMAIL = '<non-production-email>'
$env:STAGING_USER_B_PASSWORD = '<non-production-password>'
```

The accounts must be isolated non-production users. User A must have no calls in the preceding one-minute rate-limit window before the runner starts.

## Safe Execution

1. Independently confirm the exact URL is staging and obtain approval to mutate isolated staging test-user state.
2. Set the required process environment variables.
3. Run:

```powershell
.\tool\staging_validation\run_ready_backend_checks.ps1 -ConfirmStaging
```

The runner prints the target URL, rejects blank or non-HTTPS URLs, and rejects URLs that look production-like unless `ALLOW_CONFIRMED_STAGING=true` is set after independent staging confirmation. It does not invoke `db push`, migration apply/reset, or Edge Function deployment commands.

## Meaning of Results

Passing confirms only the tested staging behaviors for the supplied users and current deployment. It does not prove all RLS paths, schema compatibility, storage isolation, receipt validation, operational monitoring, or production readiness.

Production release remains **NO** until a confirmed staging project passes all database, RLS, security, monetization, storage where applicable, receipt mismatch, and shared rate-limit tests.
