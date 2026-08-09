# Blocked Test Missing Information

The following tests are intentionally not generated or executed by the ready-check runner.

## Ready Backend RPC Checks

- **Status: `PASSED_WITH_EXPECTED_SKIPS`.** The staging-only harness completed with zero failures and four intentional skips.

## Completed RLS Coverage

- Core-Sync RLS, spoofed ownership checks, and Profiles RLS passed in the approved staging-only execution.
- Monetization cross-user read isolation passed; direct monetization writes were not performed.

## Monetization Own-Record Visibility

- **Status: `BLOCKED_PENDING_APPROVED_MONETIZATION_FIXTURE_ROWS`.** User A has no naturally provisioned records in the five monetization tables, so own-record visibility was skipped rather than seeded.
- Needed: naturally provisioned User A records or explicit approval for isolated test-owned rows and cleanup.

## Storage Tests

- **Status: `READY_TO_RUN_PENDING_HUMAN_APPROVAL`.** Repository policy review, execution plan, cleanup contract, approval checklist, and a staging-locked runner are generated for `chronospark-sync` validation paths only.
- Required before execution: human confirmation of the effective staging bucket and `storage.objects` policies, accepted cleanup contract, and completed `STORAGE_VALIDATION_APPROVAL.md`.
- The runner uses only `chronospark-sync/{user-uuid}/validation/`, rejects `/backup/`, requires `-ConfirmStaging`, and uses normal User A/User B sessions plus the anon key only.

## Receipt Mismatch / `apply_verified_purchase` Tests

- **Status: `BLOCKED_PENDING_DEPLOYED_ROUTE_CONFIRMATION_GOOGLE_TEST_PATH_AND_CLEANUP_CONTRACT`.** Captured grant verification reports anon and authenticated EXECUTE denied with service_role EXECUTE retained. The captured bypass transcript reports 19 PASS, 0 FAIL, 0 SKIP, and exit status 0; direct client denial and no-mutation scope are verified.
- Grant verification evidence and bypass transcript review are complete. See `APPLY_VERIFIED_PURCHASE_BYPASS_VERIFICATION.md`.
- **Edge Function route confirmation:** confirm the deployed `monetization-verify` route matches the reviewed server-only receipt path.
- **Google test purchase path:** approve a safe staging Google Play test receipt/token path and product mapping.
- **Cleanup contract:** document test-user ownership, before/after evidence, and approved cleanup responsibility.
- [ ] Edge Function route confirmation
- [ ] Google Play test path
- [ ] cleanup contract
- Follow `MONETIZATION_VERIFY_DEPLOYMENT_REVIEW.md`, `MONETIZATION_VERIFY_OPERATOR_CONFIRMATION.md`, `MONETIZATION_VERIFY_MANUAL_CONFIRMATION_RUNBOOK.md`, and `NEXT_RECEIPT_EXECUTION_GATE.md`; do not mark receipt validation complete until the remaining route, Google test-purchase, and cleanup prerequisites have captured evidence.

## `grant_monetization_credits` Authorization

- **Status: `READY_TO_RUN_PENDING_HUMAN_APPROVAL`.** A denial-only staging harness is generated for anonymous and normal authenticated callers; it has no privileged-role path.
- Do not generate or run privileged/admin/service-role tests without explicit approval.

## Valid / Insufficient Credit Debit Tests

- **Status: `BLOCKED_PENDING_ADMIN_SETUP_CONTRACT_APPROVAL`.** Wallet tables are present, but valid/insufficient debit tests require approval of the admin setup contract and cleanup strategy.
- Needed: approved isolated wallet setup strategy.
- Needed: confirmed staging wallet balance columns and defaults.
- Needed: confirmation whether setup uses a service/admin-only path, kept outside client-side scripts.
- Needed: cleanup strategy and expected transaction-row assertions.

## Next Required Input

- `public.ai_proxy_rate_limits`: **`RPC_ONLY_TABLE_REVIEW_REQUIRED`**. It has `user_id uuid` and RLS enabled but no table policies. Local migrations revoke direct client access and grant only authenticated execution of `consume_ai_proxy_rate_limit()`; validate it through that RPC, not direct-table RLS tests.
- Rate-limit validation: **`READY_THROUGH_RPC_ONLY`**; the ready harness passed its anonymous denial and shared-session limit scenarios.
- Valid seed generation and all mutation-test execution remain separately gated.
- Production release remains **NO**.