# Receipt Hardening Recommendations

**Recommendations only. No database or Edge Function change is made by this review.**

1. A staging-first hardening migration is prepared at `supabase/migrations/20260804160000_harden_apply_verified_purchase_rpc_grants.sql`. Apply it only after explicit approval, then run the read-only grant verification before bypass-denial tests. It revokes `EXECUTE` from `PUBLIC`, `anon`, and `authenticated`, and grants it only to `service_role`.
2. Treat the Edge Function as the only receipt-validation entry point; it should derive the entitled `product_id` from Google-verified response data, not trust the client claim.
3. Add a global token replay guard and a suitable order replay guard. The current database uniqueness of `(user_id, purchase_token_hash)` does not prevent cross-user token reuse.
4. Make purchase application idempotent for retries with a canonical verified purchase/token/order identifier and an atomic uniqueness contract.
5. Keep caller-to-target binding server-side: the Edge authenticated user ID must determine the target. Do not make the RPC client-callable with a bare `target_user_id = auth.uid()` predicate when a server-only model is available.
6. Add staging receipt mismatch and replay tests only after safe Google test credentials/receipts, deployed route confirmation, cleanup, and effective-grant verification are approved.
7. Review the deployed Edge Function body and server secret boundary before treating local source as deployment proof.

## Bypass Execution Evidence

**BYPASS TEST EXECUTED BUT RESULTS NOT CAPTURED.** A manual bypass-run exit status exists, but its detailed PASS/FAIL assertions were not retained. Do not treat the bypass behavior as verified until the grant query is re-run and a complete approved rerun transcript is captured. See `APPLY_VERIFIED_PURCHASE_BYPASS_RECOVERY.md`.

## Production Release Status

**NO**