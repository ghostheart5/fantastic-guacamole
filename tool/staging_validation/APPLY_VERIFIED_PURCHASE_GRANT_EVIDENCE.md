# Apply Verified Purchase Grant Evidence

## Current Evidence

- The hardening migration exists.
- The migration is grant-only.
- The migration safety review is complete.
- Deployment status is unknown from local files.
- Effective staging grants are unknown from local files.

## Required Verification

Run the read-only SQL file manually against confirmed staging:

```text
tool/staging_validation/apply_verified_purchase_grant_verification.sql
```

## Required Capture

- anon execute boolean
- authenticated execute boolean
- service_role execute boolean

## Expected Hardened State

- anon = `false`
- authenticated = `false`
- service_role = `true`

Do not treat receipt validation as complete until the captured result is recorded in `APPLY_VERIFIED_PURCHASE_GRANT_RESULTS.md` and reviewed.

Production release remains **NO**.