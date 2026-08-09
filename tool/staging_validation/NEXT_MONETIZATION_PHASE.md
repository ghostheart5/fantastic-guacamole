# Next Monetization Phase

## Recommendation: `ADMIN_SETUP_REQUIRED`

The valid-debit test must mutate a wallet and create a transaction, but the client-side contract provides no way to restore that state. `consume_monetization_credits` can naturally create a wallet, but this does not solve deterministic baseline setup or cleanup. Existing shared wallet discovery is unsafe and non-repeatable.

Use a human-approved, external administrative setup and cleanup process for disposable staging users. Keep any privileged capability entirely outside client test scripts and do not generate it without explicit approval.

## Resulting Readiness

- Valid debit: blocked until setup, baseline, and cleanup are approved.
- Insufficient balance: blocked until an isolated known balance is available.
- Duplicate debit protection: blocked on an explicit product idempotency contract; the current function has no idempotency parameter.
- Monetization own-record visibility: partially blocked until each table has legitimate or explicitly approved isolated rows.

## Production Release Status

**NO**