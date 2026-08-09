# Staging Validation Automation Summary

## Files Verified

- `.env.example`, `README.md`, `run_ready_backend_checks.ps1`, `StagingValidation.Common.ps1`, and the five ready-check scripts.
- Local migration and Edge Function sources used to confirm function names and contracts.

## Files Created or Updated

- Updated local environment loading, target URL display order, and grant-credit skip wording in the harness.
- Added `STAGING_RUNBOOK.md`, `READY_CHECK_RESULTS_TEMPLATE.md`, `BLOCKED_TESTS_MISSING_INFO.md`, `FUNCTIONS_NEEDED_FOR_NEXT_PASS.md`, and `RECEIPT_MISMATCH_PREP.md`.

## Ready Checks Available

- Zero/negative/anonymous credit-consumption denial.
- Cross-user and anonymous denial for wallet/reset helpers.
- Profile repair, idempotency, ownership, and anonymous denial.
- Anonymous and normal-authenticated global-metrics denial.
- Shared database-backed rate limit over two sessions for the same user.

## Command

```powershell
.\tool\staging_validation\run_ready_backend_checks.ps1 -ConfirmStaging
```

## Blocked Categories

- Core-sync RLS and spoofed upserts are `TABLE_MISSING_OR_WRONG_SCHEMA`: preflight returned `exists=false` for the expected public tables.
- Storage isolation, receipt mismatch, grant-credit authorization, and valid/insufficient debit setup remain blocked.

## Schema Readiness Stop

The local migration inventory expects the named tables, but the inspected database does not currently expose `profiles`, `tasks`, `goals`, `habits`, `settings`, `purchase_bindings`, or `user_daily_metrics` in `public`. This may be missing migrations or a wrong schema/project; it cannot be distinguished without read-only migration history and schema discovery output. Do not run RLS tests or seed SQL.

## Safety Guards Confirmed

- Explicit `-ConfirmStaging` required before `.env` loading or any network operation.
- Required staging variables and HTTPS URL required.
- Target URL printed before testing and production-like URLs rejected unless separately overridden after confirmation.
- No service-role variable is accepted by the client harness.
- No database push, migration apply/reset, or function deployment command exists in the runner.

## Commands Intentionally Not Run

- No remote Supabase CLI command, database mutation, migration command, Edge deployment, Google request, or credentialed harness execution.

## Production Release Status

**NO**