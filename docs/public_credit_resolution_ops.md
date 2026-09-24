# Public credit checkout exception monitoring (draft)

This procedure applies only after the reviewed public checkout migration and verifier are deployed. It does not authorize a credit grant, Google Play refund, public sale, or production release. Public sales remain disabled while the customer-remedy policy and Play-signed delayed-payment evidence are open.

## Read-only check

Run `node scripts/check_public_credit_resolutions.mjs` from an approved server or protected job with `SUPABASE_PROJECT_REF`, `CHRONOSPARK_SUPABASE_URL`, and `SUPABASE_SECRET_KEY` supplied through its secret store. The project must be `qpwhuckyirnqtmvhpede`; the checker calls only the service-role RPC `public_credit_checkout_resolution_health`. Never put the key in a command line, report, issue, or screenshot. The RPC returns counts and the oldest unresolved timestamp, not purchase tokens, order IDs, account IDs, or wallet rows.

Status `clear` means no queued paid orders need resolution. `watch` means one or more verified orders are queued but none is over one hour old. `action_required` means at least one has waited over one hour; `critical` means at least one has waited over one day. The command exits nonzero for the latter two so a protected scheduled job can alert. **No schedule or alert recipient is activated by this draft.** A failed query is unknown state, never equivalent to `clear`.

## Operator response

1. Confirm the exact deployed migration, verifier and RTDN versions, purchase product, and public-sales flag. If the checker cannot read the queue, keep or turn public sales off through the separately reviewed rollout control and investigate the read failure. Do not infer an empty queue.
2. For a queued case, use a restricted operator surface to inspect the exact token/order/account binding and Google Play order state. Keep raw identifiers out of general logs. Confirm no wallet grant or consumption occurred. A summary count cannot decide a customer's remedy.
3. Follow the owner-approved refund or fulfillment policy. A confirmed full refund or trusted void updates the resolution state through the reviewed token-locked path. `PENDING_REFUND`, an ambiguous API timeout, or a partial refund remains unresolved and needs manual review; never blindly repeat a refund call. Do not mark an order `refunded` from a timer alone.
4. Re-run the aggregate checker and record the count change, provider evidence, disposition time, and reviewer. If a paid order remains unresolved near the provider's automatic-refund deadline, escalate to the billing owner and support contact. Those contacts and an actual paging schedule must be named before public checkout is enabled.

Google states that an unacknowledged completed one-time purchase is automatically refunded after three days; [license-test purchases can refund after about three minutes](https://developer.android.com/google/play/billing/test). The window starts after a pending purchase becomes PURCHASED, per the [pending-transaction guidance](https://developer.android.com/google/play/billing/integrate#pending). Neither period proves a refund happened for a specific order. Verify that order's actual state.
