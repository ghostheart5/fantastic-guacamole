# Apply Verified Purchase Pre-Execution Review

## Review Status

**READY_FOR_MANUAL_STAGING_HARDENING_APPROVAL**

This is a review-only record. No migration, SQL verification, Edge Function deployment, Google Play call, or bypass test was run for this review.

## Migration Review

- Reviewed migration: `supabase/migrations/20260804160000_harden_apply_verified_purchase_rpc_grants.sql`.
- The exact `public.apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb)` signature is changed only through grants.
- `EXECUTE` is revoked from `PUBLIC`, `anon`, and `authenticated`.
- `EXECUTE` is granted to `service_role`.
- The migration does not change the function body, product tiers, wallet logic, or Edge Function code.
- No table alteration, table drop, data mutation, or other destructive operation was found.
- No secrets are present in the migration.

## Target Review

- Linked project ref: `pxtjkwfedrtnxuihtdox`.
- Confirmed target: staging only.
- The staging environment URL matches `https://pxtjkwfedrtnxuihtdox.supabase.co`.
- No production marker was found in the staging environment configuration.
- The bypass runner rejects targets other than `pxtjkwfedrtnxuihtdox.supabase.co` and uses only the anon key plus normal authenticated user sessions.

## Remaining Approval

- [ ] I confirm `pxtjkwfedrtnxuihtdox` is staging.
- [ ] I confirm this is not production.
- [ ] I confirm `apply_verified_purchase` is server-only.
- [ ] I approve revoking anon EXECUTE.
- [ ] I approve revoking authenticated EXECUTE.
- [ ] I approve keeping service_role EXECUTE.
- [ ] I confirm Edge Function receipt validation remains the application path.
- [ ] I understand this changes staging database grants.
- [ ] I approve applying this hardening migration to staging only.

The approval state is **NOT APPROVED** until the final approval checklist is completed.

## Manual Execution After Approval

Run manually from the repository root:

```powershell
npx supabase db push
```

Then run:

```powershell
npx supabase migration list
```

## Required Post-Migration Verification

Manually execute the read-only SQL in:

```text
tool/staging_validation/apply_verified_purchase_grant_verification.sql
```

Proceed only when `anon_has_execute = false`, `authenticated_has_execute = false`, and `service_role_has_execute = true`.

Only then run the bypass-denial harness:

```powershell
.\tool\staging_validation\run_apply_verified_purchase_bypass_checks.ps1 -ConfirmStaging
```

## Production

Production release status: **NO**.