# Public credit late-payment recovery repair

Repair on `codex/public-credit-license-qa-3092`, based on `033ac0376b885c3f058f86efa3f3522d2c1bdfe8`. This document records source and local evidence before hosted validation. The user authorized source review, commit/push, exact-commit checks, conditional integration and rollout preparation on September 25. Live deployment, refunds, purchases and public activation are outside that preparation scope.

## Why the repair uses the existing refund remedy

If the app/backend misses pending registration and Google reports a completed purchase after the admission deadline, a retry cannot establish that Google previously reported PENDING within the deadline. The completed receipt is insufficient to distinguish an offline delayed payment from a stockpiled admission used later. The current admission rule therefore retains the verified, unfulfilled order for customer resolution without granting or consuming it.

This patch does not fabricate pending proof, extend admission expiry, store raw purchase tokens, or grant credits on client timestamps. It completes the operational wiring for the existing full-refund remedy and prevents new public sales without that remedy's enablement and release attestation. The original PR 129 review remains open for disposition of this alternative and Play runtime evidence.

## Changes

- `publicCreditSaleEnabled` additionally requires exact `true` values for `PUBLIC_CREDIT_AUTO_REFUND_ENABLED` and `CHRONOSPARK_PUBLIC_CREDIT_REFUND_READINESS_VERIFIED`. Missing/malformed values deny new public admissions. Existing paid receipts remain verifiable when new sales close; private license QA remains separately cohort-gated.
- The existing ten-minute reconciliation workflow gains a main-only, production-environment refund job. It stays disabled until repository variable `AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED` is explicitly enabled. Its own gate is independent of new-sales flags, so disabling public checkout does not stop recovery of already-paid orders.
- The new caller sends one authenticated POST to the fixed existing project/worker endpoint. It does not retry an uncertain response. The existing worker's durable claim and subsequent Google readback continue to prevent repeated refund requests.
- Output is restricted to validated aggregate counts. A requested refund is never counted as confirmed. A separate aggregate age check runs even after worker failure; deferred/manual cases and overdue payments fail the workflow for operator attention.
- CI runs the caller tests. New orchestration regressions exercise initial registration failure, late completion, durable customer-resolution response, one refund request, ambiguous response, pending refund, provider-confirmed refund, and an empty queue on a later pass. Provider and database transports are mocked in those tests; they are not SQL or Play runtime proof.

## Deployment and release acceptance, not performed

1. Review this patch against PR 129/135 and obtain an explicit disposition of the pending-binding finding. Do not label it fixed by retrospectively registering a completed receipt.
2. Validate the existing admission/resolution migration and worker deployment against the chosen source. This patch makes no schema change.
3. During an explicitly authorized rollout, configure the worker's existing restricted refund identity and reconciliation secret. The caller secret must match `PUBLIC_CREDIT_REFUND_RECONCILE_SECRET` on the worker. Require the fixed project URL; do not place credentials in documents or source.
4. Configure the repository-level scheduling variable (not merely an environment variable with the same name), enable the worker, and observe a successful source-matched scheduled run. Keep public sale flags closed while preparing and testing this path.
5. Complete exact Play-signed license tests: registration failure, app offline/killed through expiry, client recovery, RTDN-only recovery, cancel, duplicate, provider timeout, confirmed refund and no grant/consume. Verify the preserved one-time claim through uncertainty and an actionable escalation when manual review is needed. Never use a real charge for this validation.
6. Verify the aggregate monitor reaches the support owner, the escalation SLA and capacity are sufficient, and queued orders are not starved. The worker processes at most five candidates per call; the existing fairness/rotation logic and monitor must be checked against the expected volume.
7. Only after successful lifecycle evidence, applicable review, and explicit activation authorization may `CHRONOSPARK_PUBLIC_CREDIT_REFUND_READINESS_VERIFIED` be asserted and public sale gates opened. This is a release attestation, not automatic liveness detection. Revoke it and stop new admissions if the remedy is unavailable; leave authorized recovery running for existing payments.

## Local validation

Source review covered the combined admission and private-QA changes in PR 129/135: authenticated principal/cohort checks, fixed product and package checks, service-only SQL grants, admission expiry and pending binding, grant/refund serialization, uncertain refund handling, account-bound client recovery, and the disabled scheduled caller. No additional source blocker was identified in that bounded review. The existing delayed-payment P1 is still an open release finding: the fallback changes the outcome to a refund and needs explicit reviewer disposition and Play-signed lifecycle evidence. Mock transports cannot prove those external behaviors.

- Red/green proof: the new refund-readiness test and expanded required-gates test failed before the policy change and passed afterwards.
- Deno: 37 focused credit-admission, receipt, late-completion and refund tests passed; all three affected Edge entrypoints type-checked.
- Node: 37 tests passed across the new caller, existing aggregate monitor and backend preflight/rollout helpers. Transports are synthetic; no live mutation was made.
- Flutter: all 96 paywall repository tests passed. Initial combined run had one new workflow-test fixture path error; corrected workflow suite rerun passed 19/19. Original failed receipt is retained alongside the successful rerun under `artifacts/pending-payment-repair-20260925`.
- GitHub workflow policy validator passed all 12 workflows; actionlint passed both changed workflows.
- Focused Flutter analyzer reported no issues; Deno lint/format checks, both secret guards, release/version guards and `git diff --check` passed.

Remaining evidence: exact repaired-source hosted CI, independent review disposition, authorized deployment/configuration readback, operator alert delivery, and Play-signed license-test refund results. This local patch is not production release approval.
