# Receipt Cleanup Approval Contract

Status: `UNKNOWN`. No automatic, manual, or administrative cleanup is approved by this contract. The existing repository evidence shows affected state but does not identify a cleanup owner or approval authority.

| State affected by a successful receipt | Expected effect | Cleanup classification |
| --- | --- | --- |
| `monetization_purchases` | One verified purchase row per user and token hash. | `ADMIN_REQUIRED` |
| `monetization_entitlement_events` | One entitlement event is inserted. | `ADMIN_REQUIRED` |
| `monetization_subscription_statuses` | Subscription and lifetime purchases insert or update the user status row. | `ADMIN_REQUIRED` |
| `purchase_bindings` | A hash of the token is bound to the authenticated user before RPC application. | `ADMIN_REQUIRED` |
| `monetization_wallets` | Wallet is ensured; subscriptions reset allowance; lifetime or credit packs change credits and tier where applicable. | `ADMIN_REQUIRED` |
| `monetization_credit_transactions` | Subscription grants and purchase grants create audit rows. | `ADMIN_REQUIRED` |
| Failed mismatch, expiry, invalid-state, or invalid-product request | Expected to create no binding, RPC mutation, entitlement, or wallet change. | `AUTOMATIC` only when no mutation is verified |

## Required owner and authority

- Cleanup owner: **UNKNOWN**. An explicitly named staging database/monetization administrator is required.
- Approval authority: **UNKNOWN**. The authority must approve the exact affected user IDs, product IDs, retention requirement, and cleanup method before a purchase is made.
- Client scripts must not perform cleanup and must not use service-role credentials.

## Approval inputs

- Test-user labels and staging account IDs.
- Scenario IDs, product IDs, purchase types, redacted token/order fingerprints, and expected state mutations.
- A statement covering whether Google Play cancellation/refund is required independently of database cleanup.
- An approved retention decision for audit rows and token hashes.

## Cleanup verification steps

1. The approved owner records the pre-test state for only the designated test users.
2. After evidence capture, the owner identifies rows by approved test-user and redacted receipt correlation data.
3. The owner performs the separately approved privileged cleanup method; this document does not prescribe SQL or authorize its execution.
4. The owner verifies the intended post-cleanup state for purchases, entitlements, subscription status, bindings, wallet, and credit transactions.
5. The owner records a redacted before/after summary and signs the cleanup disposition.
6. Any residual Google Play purchase lifecycle is reconciled under the approved Google Play owner; database cleanup alone does not cancel a store purchase.
