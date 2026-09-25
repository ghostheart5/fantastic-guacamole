# Public credit checkout exception monitoring (draft)

The owner selected a **full Google Play refund** for a verified credit-pack payment that cannot safely receive credits. This choice applies to exceptional failed orders, not normal sales. This draft procedure and code do not authorize a live refund, public sale, or production release. Public sales remain disabled until the refund worker, protected invocation, Play-signed delayed-payment evidence, qualified reviews, and support operation are approved and verified.

## Read-only check

Run `node scripts/check_public_credit_resolutions.mjs` from an approved server or protected job with `SUPABASE_PROJECT_REF`, `CHRONOSPARK_SUPABASE_URL`, and `SUPABASE_SECRET_KEY` supplied through its secret store. The project must be `qpwhuckyirnqtmvhpede`; the checker calls only the service-role RPC `public_credit_checkout_resolution_health`. Never put the key in a command line, report, issue, or screenshot. The RPC returns counts and the oldest unresolved timestamp, not purchase tokens, order IDs, account IDs, or wallet rows.

Status `clear` means no queued paid orders need resolution. `watch` means one or more verified orders are queued but none is over one hour old. `action_required` means at least one has waited over one hour; `critical` means at least one has waited over one day. The command exits nonzero for the latter two so a protected scheduled job can alert. **No schedule or alert recipient is activated by this draft.** A failed query is unknown state, never equivalent to `clear`.

## Independent monitoring and notification drill

`Backend Reconciliation` now has two narrowly scoped manual operations:

- `check-credit-resolutions` runs the read-only health RPC, even while automatic refunds and public checkout remain disabled. Its job summary reports only aggregate counts. A failed query reports `unknown` and fails the job; it cannot report an empty queue.
- `test-credit-alert` uses synthetic overdue counts through the same classifier and intentionally fails the named **Axiomara billing ALERT DRILL** job. It has no production environment, database credentials, provider credentials or refund call. Confirm delivery of the notification for that exact run to the configured billing owner before recording the alert gate as passed. A local test or failed job alone is not email delivery proof.

The separate scheduled monitor requires repository variable `AXIOMARA_PUBLIC_CREDIT_MONITOR_ENABLED=true` and reviewed code on `main`. It does not depend on the refund enablement variable. This change does not activate that schedule. Manual operations are limited to `main` and the existing private license-QA branch.

GitHub Actions email notifications must be enabled for the workflow actor and routed to the approved billing address. Scheduled notifications follow the schedule's actor; verify that identity again when integrating or changing the cron schedule. See [GitHub workflow notifications](https://docs.github.com/en/actions/concepts/workflows-and-actions/notifications-for-workflow-runs). Receiving a manually triggered drill does not prove future scheduled delivery. Record the recipient and receipts in the restricted release packet, not this public repository.

The database gate also runs `scripts/integration/public_credit_refund_database_test.ts` against its disposable loopback Supabase instance. Actual SQL claims and queue transitions are exercised across repeated worker calls after a simulated lost provider response. The test checks pending and partial refunds, full confirmation, the revoked tombstone and exactly one outbound refund request. Its provider is synthetic, its network access is restricted to loopback, and it is not live Google refund evidence.

## Operator response

### Isolated manual refund operation

After separate approval and enablement, select `reconcile-credit-refunds` in
`Backend Reconciliation` to invoke only the refund worker and its health check.
The legacy `reconcile` operation runs account-deletion reconciliation only;
it no longer starts a manual refund run. Scheduled reconciliation is unchanged.
The refund operation still requires reviewed source on `main`, the protected
`production` environment, `AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED=true`, and the
server's independent refund enablement. Adding this choice does not enable any
of those controls or bypass environment branch protection.

This operation processes the worker's bounded eligible queue, not a nominated
test order. It is not a license-test-only mode. Before any approved live test,
verify the eligible queue and use an appropriately isolated test setup; do not
enable it merely to obtain a green workflow run. A skipped job is not execution
or refund evidence.

1. Confirm the exact deployed migration, verifier and RTDN versions, purchase product, and public-sales flag. If the checker cannot read the queue, keep or turn public sales off through the separately reviewed rollout control and investigate the read failure. Do not infer an empty queue.
2. For a queued case, use a restricted operator surface to inspect the exact token/order/account binding and Google Play order state. Keep raw identifiers out of general logs. Confirm no wallet grant or consumption occurred. A summary count cannot decide a customer's remedy.
3. Follow the owner-selected full-refund policy. The draft `public-credit-refund-reconcile` Edge Function is **default disabled** and requires its own protected invocation secret and a dedicated `GOOGLE_REFUND_SERVICE_ACCOUNT_JSON` credential, separate from the purchase verifier's service account. Grant the refund credential only the Play order permissions needed for this function. When enabled after review, it reads a bounded service-only queue, checks Google's exact order ID, purchase-token hash, one-time product and quantity, and claims one refund attempt under the token lock before calling `orders.refund` with `revoke=true`. Only a later Google `REFUNDED` readback or trusted void closes the queue. `PENDING_REFUND`, an ambiguous API timeout, a partial refund, a mismatched order, or a prior attempt still showing `PROCESSED` needs manual review; never blindly repeat a refund call. A worker crash after the one-time claim and before the POST also needs manual review.
4. Re-run the aggregate checker and record the count change, provider evidence, disposition time, and reviewer. If a paid order remains unresolved near the provider's automatic-refund deadline, escalate to the billing owner and support contact. Those contacts and an actual paging schedule must be named before public checkout is enabled.

No protected invocation schedule, alert destination, or `PUBLIC_CREDIT_AUTO_REFUND_ENABLED=true` setting exists in this draft. Before enabling, use Play-signed license tests for delayed approval while online and offline, cancellation, a lost provider response, RTDN-only arrival, provider full and partial refunds, and duplicate worker invocation. Confirm the specific order reaches `REFUNDED` and the queue reaches `refunded` without credits or consumption. Record the support owner and an escalation path for `manualReview` and `retryLater` results. Keep public sales off if the worker or its monitoring cannot run.

Google states that an unacknowledged completed one-time purchase is automatically refunded after three days; [license-test purchases can refund after about three minutes](https://developer.android.com/google/play/billing/test). The window starts after a pending purchase becomes PURCHASED, per the [pending-transaction guidance](https://developer.android.com/google/play/billing/integrate#pending). Neither period proves a refund happened for a specific order. Verify that order's actual state.
