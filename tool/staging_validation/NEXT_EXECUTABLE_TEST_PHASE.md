# Next Executable Test Phase

**Staging-only readiness report. Do not run any test until the relevant execution approval is granted.**

## Ready Now

- Core-sync RLS: `tasks`, `goals`, `habits`, `settings`, `purchase_bindings`, and `user_daily_metrics`; exact payload mappings are documented in [CORE_SYNC_INSERT_PAYLOADS.md](CORE_SYNC_INSERT_PAYLOADS.md).
- Profiles RLS: use custom ownership mapping `id = auth.uid()`.
- Monetization read isolation: all five reviewed monetization tables are ready for read-isolation implementation.

Ready means test assets can be implemented. It does not authorize execution, data setup, or cleanup mutations.

## Still Blocked

| Category | Status | Exact missing information |
| --- | --- | --- |
| Valid debit | `BLOCKED_NEEDS_APPROVED_WALLET_SETUP_AND_CLEANUP` | Approved isolated wallet balance setup, test-row ownership, cleanup procedure, and expected balance/transaction assertions. |
| Insufficient balance | `BLOCKED_NEEDS_APPROVED_WALLET_SETUP_AND_CLEANUP` | Same isolated wallet setup and cleanup, plus an approved insufficient-balance precondition. |
| `grant_monetization_credits` authorization | `BLOCKED_NEEDS_EXACT_AUTHORIZATION_TEST` | Staging-effective function signature, grants, server/admin authorization boundary, and an approved non-service-role denial scenario. |
| Receipt mismatch | `BLOCKED_NEEDS_EDGE_FUNCTION_ROUTE_AND_SAFE_GOOGLE_TEST_RECEIPT_PATH` | Deployed staging Edge Function route, safe Google test receipt/token path, product mapping, and cleanup/duplicate-receipt strategy. |
| Storage | `BLOCKED_NEEDS_BUCKET_PATH_POLICY_CONTRACT` | Confirmed bucket name, object-path convention, effective `storage.objects` policies, and approved upload/read/delete cleanup contract. |
| `apply_verified_purchase` validation | `BLOCKED_NEEDS_EDGE_FUNCTION_ROUTE_AND_SAFE_GOOGLE_TEST_RECEIPT_PATH` | Same deployed receipt-validation route and safe test receipt prerequisites. |

## Excluded From Direct Table Testing

`ai_proxy_rate_limits` remains RPC-only. Validate it through `consume_ai_proxy_rate_limit()`; the ready backend harness already covered anonymous denial and shared-session rate limiting.

## Production Release Status

**NO**
