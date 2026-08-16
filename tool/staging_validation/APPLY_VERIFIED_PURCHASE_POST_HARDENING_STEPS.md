# Apply Verified Purchase Post-Hardening Steps

Complete these steps only after the final staging approval is recorded.

1. Confirm the Supabase CLI is linked to `RETIRED_STAGING_PROJECT`.
2. Apply the approved migration to staging.
3. Run `npx supabase migration list`.
4. Run `tool/staging_validation/apply_verified_purchase_grant_verification.sql` against staging.
5. Confirm `anon_has_execute` is `false`.
6. Confirm `authenticated_has_execute` is `false`.
7. Confirm `service_role_has_execute` is `true`.
8. Run the bypass-denial harness.
9. Confirm anonymous, User A, and User B calls are denied.
10. Confirm no client-visible purchase, entitlement, or wallet state changed.
11. Keep receipt-mismatch tests blocked until the deployed Edge Function route and a safe Google Play test-receipt path are confirmed.

## Commands

```powershell
npx supabase db push
npx supabase migration list
```

Run the verification SQL manually in the confirmed staging SQL environment:

```text
tool/staging_validation/apply_verified_purchase_grant_verification.sql
```

Only after the grant results match the expected values, run:

```powershell
.\tool\staging_validation\run_apply_verified_purchase_bypass_checks.ps1 -ConfirmStaging
```

Production release remains **NO**.
