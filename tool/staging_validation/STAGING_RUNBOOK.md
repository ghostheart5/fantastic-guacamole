# Staging Validation Runbook

## Pre-Run Checklist

- Confirm the exact Supabase project and URL are staging, not production.
- Confirm `staging_user_a` and `staging_user_b` are isolated non-production accounts.
- Confirm `.env` contains staging-only values and is not tracked by Git.
- Confirm the harness uses only `STAGING_SUPABASE_ANON_KEY`; no service-role or secret key is used.
- Confirm approved cleanup for profile repair and rate-limit test state.
- Confirm production release remains blocked.

## Confirmed Staging Project

- `pxtjkwfedrtnxuihtdox` is the confirmed ChronoSpark staging project.
- Expected base URL: `https://pxtjkwfedrtnxuihtdox.supabase.co`
- `qpwhuckyirnqtmvhpede` is not the staging target for this validation.
- Every command must point to `pxtjkwfedrtnxuihtdox`. If a command or CLI link points to `qpwhuckyirnqtmvhpede`, stop.

## Migration State Finding

- The CLI is linked to `pxtjkwfedrtnxuihtdox`.
- `npx supabase migration list` shows local migrations, but the Remote column is blank for every listed migration.
- This suggests staging does not yet have the tracked schema, or its migration history is not recorded.
- Run the read-only discovery SQL before any mutation.
- No test that requires tables can run yet.

## Environment Setup

From this directory, copy `.env.example` to `.env`, then fill only these variables:

```text
STAGING_SUPABASE_URL=
STAGING_SUPABASE_ANON_KEY=
STAGING_USER_A_EMAIL=
STAGING_USER_A_PASSWORD=
STAGING_USER_B_EMAIL=
STAGING_USER_B_PASSWORD=
```

The runner loads this file only after `-ConfirmStaging` is supplied. It does not print its key or passwords.

## Confirmed User UUIDs

- User A UUID: `a6dc2118-2140-4416-8642-9c3eba691288`
- User B UUID: `aa116396-4dc1-461e-8502-61b6896570b4`

Emails and passwords remain only in the local `.env`; do not add them to generated documents. These UUIDs do not prove that tables, ownership columns, or RLS are ready. Run schema discovery before any core-sync RLS test.

## Run Order

1. Independently confirm the URL and project are staging.
2. Ensure user A has no AI rate-limit calls in the preceding minute.
3. From the repository root, run:

```powershell
.\tool\staging_validation\run_ready_backend_checks.ps1 -ConfirmStaging
```

The runner prints the confirmed target URL, rejects missing configuration and non-HTTPS URLs, and accepts only the exact confirmed staging base host. It does not run database pushes, migration commands, resets, or function deployments.

## Schema Missing / Wrong Schema Stop Condition

The preflight check returned `exists=false` for public `profiles`, `tasks`, `goals`, `habits`, `settings`, `purchase_bindings`, and `user_daily_metrics`. Classify these as `TABLE_MISSING_OR_WRONG_SCHEMA`.

- If expected tables do not exist in `public` or another expected schema, do not run RLS tests.
- If tables exist in a different schema, update the harness schema mapping from discovery output; do not invent public tables.
- If tables do not exist anywhere, staging migrations have not been applied or the wrong project is connected.
- Do not run seed SQL, RLS mutation tests, or production migrations to resolve this condition.

After explicitly confirming a target is staging, the read-only migration-history command is:

```powershell
npx supabase migration list
```

Use [schema_discovery.sql](schema_discovery.sql) and [function_discovery.sql](function_discovery.sql) through an approved read-only inspection path. Do not run database push, migration apply, or reset commands.

## Discovery Before Mutation

1. Run schema discovery first in the confirmed staging project.
2. Run function discovery second in the confirmed staging project.
3. Review the already-confirmed migration finding: local migrations have blank Remote values.
4. Only then decide whether RLS tests can be generated.

Do not run seed SQL or mutation tests until the schema and RLS state is confirmed.

## What Passing Means

The ready RPC checks passed against the confirmed staging project for the supplied test users: credit-input denial, wallet/reset helper denial, profile repair/idempotency, global-metrics denial, and shared database-backed rate limiting.

## What Passing Does Not Mean

Passing does not validate core-sync RLS, spoofed upserts, storage isolation, receipt mismatch behavior, `grant_monetization_credits`, or valid/insufficient credit debits without an approved wallet setup. It does not allow production release.

## Failure Triage

- An unexpected success on a denial test is a security bug. Preserve the output and stop release promotion.
- An unexpected profile-repair failure may indicate provisioning, EXECUTE grant, or RLS drift.
- Unexpected rate-limit behavior may indicate the database-backed limiter is absent, misconfigured, or not wired into the deployed path.
- Do not weaken RLS, broaden grants, or add service-role credentials to make a test pass.

Production release remains **NO** until all backend validation categories pass in confirmed staging.