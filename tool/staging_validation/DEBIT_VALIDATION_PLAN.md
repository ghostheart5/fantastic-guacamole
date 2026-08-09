# Debit Validation Plan

**Plan only. Requires [WALLET_TEST_APPROVAL.md](WALLET_TEST_APPROVAL.md) and an approved disposable-user wallet setup/cleanup contract.**

## Preconditions

- Confirmed staging only.
- A disposable test user with a documented baseline wallet and transaction count.
- Approved external cleanup that removes or restores all test-caused wallet and transaction state.
- Normal authenticated test session only; no privileged credential in client scripts.

## 1. Valid Debit Execution

Call `consume_monetization_credits(credit_amount, reason, metadata)` as the owner with a positive amount no greater than the approved baseline balance.

Expected: HTTP success, `allowed = true`, and returned balance reflects exactly one debit.

## 2. Insufficient Balance Execution

Call as the owner with an amount greater than the known available balance but within the function’s accepted argument range.

Expected: the function rejects for insufficient credits, and the wallet balances and transaction count remain unchanged from the pre-call snapshot. The current hardened implementation raises an error rather than returning an `allowed = false` row.

## 3. Duplicate Debit Protection

The function signature has no idempotency key or request identifier. The reviewed implementation records a spend transaction for each successful invocation, so it does not provide duplicate-request protection by itself.

Do not assert that a repeated call is automatically deduplicated. Before a duplicate-debit test can be defined, obtain a product decision and a duplicate-detection contract, such as an idempotency key or an external request ledger. Until then, duplicate debit protection remains a design gap, not an executable validation.

## 4. Anonymous Caller Rejection

Call the RPC with only the anon key and no user session.

Expected: authorization failure; no caller wallet is provisioned and no transaction row appears.

## 5. Balance Verification

Capture owner-visible fields before and after each case: `balance`, `allowance_remaining`, `bonus_balance`, and `lifetime_spent`.

- Valid debit: expected fields change exactly per the debit amount and bonus-first consumption rule.
- Failed/anonymous debit: all fields remain unchanged.

## 6. Transaction Verification

Capture the owner-visible transaction count and a pre-run boundary. A valid debit creates exactly one new `spend` transaction with negative amount, the requested reason, and matching `balance_after`. Failed and anonymous calls create no transaction.

## 7. Cleanup Verification

After test execution, the approved external cleanup confirms no test wallet balance mutation or test transaction remains. If cleanup cannot restore the documented baseline, stop and mark the run failed for manual review.