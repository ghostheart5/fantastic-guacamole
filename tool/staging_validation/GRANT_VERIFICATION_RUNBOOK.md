# Grant Verification Runbook

Perform these steps manually and only against staging.

1. Open staging project `RETIRED_STAGING_PROJECT`.
2. Open the SQL Editor.
3. Run `tool/staging_validation/apply_verified_purchase_grant_verification.sql`.
4. Save the results in `APPLY_VERIFIED_PURCHASE_GRANT_RESULTS.md`.
5. Record:
   - anon execute
   - authenticated execute
   - service_role execute
6. PASS conditions:
   - anon = `false`
   - authenticated = `false`
   - service_role = `true`
7. If PASS, proceed to bypass transcript review.
8. If FAIL, receipt validation remains blocked.

Do not run this procedure against production. Do not copy secrets into the evidence record.

Production release remains **NO**.
