# Receipt Replay Test Plan

Status: execution plan only. The first successful purchase requires cleanup approval before replay validation can begin.

## Duplicate token reuse

- First request: User A verifies a unique approved test token.
- Same-user repeat: User A resubmits that token.
- Expected result: token binding accepts the same owner; `apply_verified_purchase` finds the existing `(user_id, purchase_token_hash)` and returns `applied: false, duplicate: true`; no second purchase, entitlement event, wallet grant, or credit transaction is created.
- Required evidence: redacted token fingerprint; both response summaries; User A before/after purchase, entitlement, wallet, and transaction counts.

## Duplicate order reuse

- The repository has no unique constraint on `order_id`; the application RPC deduplicates by user plus purchase-token hash.
- Do not claim order-level replay protection without an approved test demonstrating its behavior.
- Required evidence: redacted order fingerprint associated with the token replay result and an explicit statement that the tested deduplication key was token hash, not order ID.

## Repeated verification calls

- Reissue the same authenticated request only after the first response is captured.
- Expected result: no duplicate monetary grant. The RPC duplicate response is the expected idempotency control.
- Required evidence: ordered timestamps, redacted request correlation, response `applied`/`duplicate` fields where available, and no-increment wallet/transaction evidence.

## Repeated Edge Function requests from another user

- User B submits User A's already-bound token while authenticated as User B.
- Expected result: `purchase binding failed`; no RPC call, User B purchase row, entitlement event, wallet mutation, or credit transaction.
- Required evidence: separate User A and User B state observations, with all token/order data redacted.

## Cleanup

- The first successful receipt remains `ADMIN_REQUIRED` under the cleanup approval contract.
- Rejected repeat and cross-user requests require no cleanup only after approved evidence confirms no mutation.
