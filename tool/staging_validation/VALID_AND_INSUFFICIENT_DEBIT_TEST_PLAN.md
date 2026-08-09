# Valid and Insufficient Debit Test Plan

**Execution status: NOT APPROVED. Requires approved admin fixture setup and cleanup.**

| Test | Required precondition | Expected result | Cleanup responsibility | Automatable later |
| --- | --- | --- | --- | --- |
| Confirm User A wallet baseline | Documented disposable User A fixture exists. | Owner-visible wallet equals the approved baseline. | Admin operator verifies baseline. | Yes, after fixture contract approval. |
| Valid small positive consume | User A balance exceeds a documented positive amount. | `consume_monetization_credits` succeeds with `allowed = true`. | Admin restores baseline/removes disposable fixture. | Yes. |
| Exact one balance decrement | Valid consume response and before/after snapshot exist. | Balance changes exactly once by the requested amount, using bonus balance first when present. | Admin verifies restored values. | Yes. |
| One transaction record | Transaction count boundary is recorded. | Exactly one new User A `spend` transaction with negative amount and matching `balance_after`. | Admin removes/restores test-created transaction state. | Yes. |
| Insufficient consume | Known balance is lower than requested amount while request arguments remain valid. | RPC fails with insufficient credits. | No state should need cleanup; verify unchanged baseline. | Yes. |
| Failed-debit state check | Before/after snapshot for insufficient call exists. | Wallet fields and transaction count remain unchanged. | Manual review if any change appears. | Yes. |
| User B cross-user isolation | User A wallet/transactions exist. | User B sees zero User A wallet/transaction rows or receives denial. | None. | Yes. |
| Post-test cleanup | All preceding results recorded. | Baseline is restored or disposable wallet/fixture rows are removed. | Admin operator. | Yes, only with approved external cleanup. |

## Duplicate Debit Constraint

Do not run a duplicate-success test as though idempotency exists. The current RPC has no idempotency key; duplicate prevention needs an explicit product contract first.