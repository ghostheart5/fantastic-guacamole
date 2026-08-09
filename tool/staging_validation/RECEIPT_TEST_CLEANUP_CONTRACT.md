# Receipt Test Cleanup Contract

No cleanup action is authorized by this contract. Assign an approved owner before receipt tests create state.

| Object | Cleanup expectation | Current classification |
| --- | --- | --- |
| `monetization_purchases` | Preserve test identifiers, inspect before/after state, then use an approved privileged cleanup process if a dedicated test user is reused. | Admin cleanup required |
| `monetization_entitlement_events` | Record expected event IDs and remove only through an approved privileged cleanup process when test-created. | Admin cleanup required |
| `monetization_subscription_statuses` | Use natural expiration/cancel only for the Google Play lifecycle; any database-row cleanup requires approved privileged handling. | Natural expiration/cancel only |
| `monetization_wallets` | Never adjust through client scripts; restore or remove dedicated test-user state only through approved privileged handling. | Admin cleanup required |
| `monetization_credit_transactions` | Preserve audit evidence and remove only through an approved privileged cleanup process if policy permits. | Admin cleanup required |
| `purchase_bindings` | Retain token-hash evidence until review completes; remove test-only binding only through approved privileged handling. | Test-only fixture cleanup |
| Test metadata, order IDs, and token hashes | Use redacted identifiers in reports; retain sufficient evidence for replay review, then remove test-only metadata through the approved owner. | Test-only fixture cleanup |
| Failed mismatch or bypass probes that create no state | Record the no-mutation result. | No cleanup needed |

Any unlisted table, external purchase lifecycle, refund/cancel procedure, or retention obligation is **not yet known** until the staging and Google Play owners approve it.

Production release remains **NO**.