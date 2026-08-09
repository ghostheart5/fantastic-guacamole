# Core-Sync RLS Execution Results

**Execution approval status at execution:** `APPROVED_FOR_CONFIRMED_STAGING_ONLY`

## Command Run

`.\staging_validation\run_core_sync_rls_checks.ps1 -ConfirmStaging`

## Target URL

`https://pxtjkwfedrtnxuihtdox.supabase.co`

## User A UUID

`a6dc2118-2140-4416-8642-9c3eba691288`

## User B UUID

`aa116396-4dc1-461e-8502-61b6896570b4`

## Tables Tested

- Core-Sync: `tasks`, `goals`, `habits`, `settings`, `purchase_bindings`, `user_daily_metrics`.
- Profiles using `profiles.id = auth.uid()`.
- Monetization read isolation: `monetization_subscription_statuses`, `monetization_wallets`, `monetization_credit_transactions`, `monetization_purchases`, `monetization_entitlement_events`.

## Tests Passed

`63`

## Tests Failed

`0`

## Tests Skipped

`5`

## Failed Suites

`0`

## Cleanup Result

`PASSED`: Core-Sync test-owned rows were owner-cleaned; spoof-row cleanup and profile restoration did not produce a failure.

## Unexpected Access Allowed

`None observed.`

## Unexpected Denial

`None observed.`

## Core-Sync RLS Results

`PASSED` for `tasks`, `goals`, `habits`, `settings`, `purchase_bindings`, and `user_daily_metrics`, including own-row access, cross-user denial, and spoofed `user_id` denial checks.

## Profiles RLS Results

`PASSED` using `profiles.id = auth.uid()` ownership mapping.

## Monetization Read-Isolation Results

`PASSED_WITH_EXPECTED_OWN_ROW_SKIPS`: cross-user denial passed for all five monetization tables. No direct writes were performed.

## Skipped Tests and Reasons

`5` expected skips: User A had no naturally provisioned own records in each monetization table, so own-record visibility was recorded as `NO_OWN_ROW_AVAILABLE` rather than fabricated with seed data.

## Security Risks Closed by This Run

- Core-Sync cross-user read, update, delete, and ownership-spoof checks for all six covered tables.
- Profile cross-user isolation using the actual `id = auth.uid()` ownership contract.
- Monetization cross-user read isolation for all five covered tables.

## Risks Not Closed by This Run

- Valid/insufficient debit setup and execution.
- `grant_monetization_credits` authorization denial.
- Receipt mismatch / `apply_verified_purchase` validation.
- Storage policy-contract validation.
- Monetization own-record visibility where no naturally provisioned User A records exist.

## Remaining Blockers

- Valid/insufficient debit setup.
- `grant_monetization_credits` authorization.
- Receipt mismatch / `apply_verified_purchase`.
- Storage policy-contract validation.

## Production Release Status

**NO**