# Wallet Admin Setup Contract

**ADMIN ONLY. STAGING ONLY. NOT APPROVED.**

## Purpose

Define the human-approved setup and cleanup required to validate valid and insufficient wallet debits deterministically. This contract does not authorize execution.

## Scope

- Target only `pxtjkwfedrtnxuihtdox`.
- Admin setup must never run from Flutter or other client code.
- Admin setup must never use production credentials or target a production project.
- A human must explicitly approve setup before execution.

## Required Setup State

### User A

- Must be a confirmed disposable staging user.
- Must have a documented baseline `monetization_wallets` row.
- Baseline must include a positive balance sufficient for one small valid debit and a later insufficient-balance attempt.
- The fixture must record all baseline wallet fields and pre-existing transaction count before any mutation.

### User B

- Needed only for cross-user wallet/transaction visibility checks.
- Must be a confirmed disposable staging user with a known wallet and transaction fixture when own-row visibility is included.

## Starting Balance and Transaction Fixtures

- Use a documented starting credit amount selected by the approving operator.
- The starting balance must be greater than the valid debit amount.
- Any fixture transaction must be identifiable through approved metadata and recorded in the test report.
- Do not assume a transaction fixture proves debit behavior; only the later consume RPC validation does that.

## Cleanup Requirements

- Restore the exact documented wallet baseline or remove all wallet/transaction rows created for confirmed disposable users.
- Confirm post-cleanup wallet fields and transaction count match the recorded baseline.
- If cleanup cannot be completed, stop and mark the validation failed for manual review.

## Permitted Data

- Wallet fixture for a confirmed disposable staging user.
- Credit transaction fixture tied to that wallet when required for visibility checks.
- Test report metadata that contains no secret values.

## Data To Remove or Restore

- Any wallet balance, allowance, bonus, lifetime, tier, and period values changed by setup or debit tests.
- Every fixture or debit-created credit transaction.
- Any User B fixture created solely for visibility checks.

## Prohibited Actions

- Production access, production credentials, or client-side privileged credentials.
- Automatic setup or cleanup from Flutter/client code.
- Changes to RLS, migrations, database reset, deployment, or unrelated seeding.

## Production Release Status

**NO**