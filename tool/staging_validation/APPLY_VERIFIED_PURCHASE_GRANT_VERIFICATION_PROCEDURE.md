# Apply Verified Purchase Grant Verification Procedure

Run this procedure manually against confirmed staging only after the approved hardening migration is applied. Do not run it against production.

## SQL File

Run the read-only file:

```text
tool/staging_validation/apply_verified_purchase_grant_verification.sql
```

## Expected Result

- `anon_has_execute = false`
- `authenticated_has_execute = false`
- `service_role_has_execute = true`

## Failure Conditions

- `anon_has_execute = true`
- `authenticated_has_execute = true`
- `service_role_has_execute = false`
- The expected function signature is absent or the query returns an unexpected result.

On any failure, stop. Do not run the bypass harness or receipt tests.

## Evidence Capture Format

Record the following in `APPLY_VERIFIED_PURCHASE_BYPASS_RESULTS.md`:

```text
Target project: pxtjkwfedrtnxuihtdox
SQL file: tool/staging_validation/apply_verified_purchase_grant_verification.sql
Timestamp (UTC): <value>
anon_has_execute: <true|false>
authenticated_has_execute: <true|false>
service_role_has_execute: <true|false>
Execute grants: <redacted catalog summary>
Review outcome: <PASS|FAIL>
```

Do not place connection strings, credentials, or other secrets in the captured evidence.

Production release remains **NO**.