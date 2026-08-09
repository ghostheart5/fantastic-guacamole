# Receipt Mismatch Threat Model

| Threat | Expected safe behavior | Local-code assessment |
| --- | --- | --- |
| Lower-tier token submitted as higher-tier product | Reject before applying entitlement. | Subscription helper requires a matching Google line item; covered by local unit test. |
| Valid token with mismatched client product ID | Reject and derive grants only from verified Google product. | Subscription path rejects mismatch. One-time path relies on product-specific Google endpoint plus allow-list; deployment evidence still needed. |
| Expired subscription | Reject without state mutation. | Subscription helper rejects expiry at or before current time. |
| Missing `lineItems` | Reject without state mutation. | Subscription helper rejects missing/non-array line items. |
| Invalid subscription state | Reject without state mutation. | Subscription helper allows only active and grace-period states. |
| Replayed token/order | Bind token globally to one user and idempotently apply once. | Edge token binding is user-bound, but database purchase uniqueness is only `(user_id, purchase_token_hash)` and `order_id` is not unique. |
| `target_user_id` spoofing | Ignore client target and use authenticated identity. | Edge path uses authenticated user ID. Database function does not enforce it. |
| Direct RPC bypassing Edge Function | Deny client execution. | Unsafe while discovery reports anon/authenticated EXECUTE. |
| Anon/authenticated `apply_verified_purchase` misuse | Deny before body execution. | Local migration intends denial; staging-effective grants must be hardened and re-verified. |

## Required Safe Contract

The granted product must come from Google-verified evidence, the token must be bound globally to its first entitled user, application must be idempotent, and the client must have no direct database RPC path. No receipt mismatch test should be generated until these deployment-state conditions and a safe Google test receipt are available.