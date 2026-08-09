# Apply Verified Purchase Bypass Capture Requirements

Use these requirements only after captured grant verification shows the expected server-only grants.

## Output Location

From the repository root, save complete runner output to:

```text
tool/staging_validation/apply_verified_purchase_bypass_rerun_output.txt
```

Use the documented capture command in `APPLY_VERIFIED_PURCHASE_BYPASS_RERUN_INSTRUCTIONS.md`.

## Required Evidence

- Confirmed staging target URL.
- Every `PASS` line.
- Every `FAIL` line.
- Every `SKIP` line.
- Final `Summary: PASS ... | FAIL ... | SKIP ...` count.
- Process exit status.
- User A wallet no-mutation result.
- User B wallet no-mutation result.
- User A entitlement-event no-mutation result.
- User B entitlement-event no-mutation result.
- User A purchase-row no-mutation result.
- User B purchase-row no-mutation result.

The transcript must show denial results for anonymous, User A-to-A, User A-to-B, User B-to-B, and User B-to-A direct RPC attempts.

Do not capture raw credentials, access tokens, purchase tokens, or privileged keys.

Production release remains **NO**.