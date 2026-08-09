# Apply Verified Purchase Grant Re-Verification Instructions

Use this procedure only after staging approval. It does not authorize production work.

## Target Confirmation

1. Confirm the Supabase CLI is linked to `pxtjkwfedrtnxuihtdox`.
2. Confirm `pxtjkwfedrtnxuihtdox` is staging and production is not targeted.
3. Do not use client credentials with elevated database privileges.

## Apply Only If Needed

If the hardening migration has not already been applied and approval is recorded, run manually from the repository root:

```powershell
npx supabase db push
```

## Read-Only Grant Verification

After the migration application, run this file manually in the approved staging SQL environment:

```text
tool/staging_validation/apply_verified_purchase_grant_verification.sql
```

Required result:

- `anon_has_execute = false`
- `authenticated_has_execute = false`
- `service_role_has_execute = true`

If `anon_has_execute` or `authenticated_has_execute` is `true`, stop. Do not run the bypass harness. Record the output in `APPLY_VERIFIED_PURCHASE_BYPASS_RESULTS.md` and investigate the effective staging grants.

Production release remains **NO**.