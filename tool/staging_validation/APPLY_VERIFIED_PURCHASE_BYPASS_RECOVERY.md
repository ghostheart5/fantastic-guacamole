# Apply Verified Purchase Bypass Recovery

## Recorded Execution

The manually invoked command was:

```powershell
.\tool\staging_validation\run_apply_verified_purchase_bypass_checks.ps1 -ConfirmStaging
```

An exit status was recorded, but the full runner transcript was not retained.

## Missing Evidence

- Individual PASS or FAIL results for all anonymous, User A, and User B direct-RPC denial probes.
- PASS or FAIL results for User A and User B no-mutation assertions.
- Final PASS, FAIL, and SKIP summary counts.
- The target and grant-state evidence paired with that run.

## Verification Status

The exit status alone cannot prove the runner reached every assertion, that every direct call was denied, or that no wallet, purchase, or entitlement state changed. The result is **not verified**.

## Rerun Requirements

1. Record final staging approval for `pxtjkwfedrtnxuihtdox`.
2. Run `tool/staging_validation/apply_verified_purchase_grant_verification.sql` in the approved staging SQL environment.
3. Confirm `anon_has_execute = false`, `authenticated_has_execute = false`, and `service_role_has_execute = true`.
4. Capture the complete console output and exit status of the approved command below.
5. Preserve the transcript with the verified staging target and timestamp in the execution record.

```powershell
.\tool\staging_validation\run_apply_verified_purchase_bypass_checks.ps1 -ConfirmStaging
```

## Required Captured Output

- The confirmed staging target output.
- PASS or FAIL output for all five direct-RPC caller/target combinations.
- PASS or FAIL output for both User A and User B no-mutation checks.
- The final `Summary: PASS ... | FAIL ... | SKIP ...` line.
- Process exit status.

## Expected PASS Conditions

- Anonymous, User A, and User B direct RPC calls are denied for every tested target.
- User A and User B show no client-visible balance, bonus balance, lifetime-earned, purchase-count, or entitlement-event-count change.
- The summary reports zero failures and the process exits successfully.

## Expected FAIL Conditions

- Any anonymous or authenticated direct RPC call succeeds.
- Any baseline or post-probe read fails.
- Any client-visible wallet, purchase, or entitlement state changes after a denied probe.
- The summary reports one or more failures or the process exits unsuccessfully.

Production release remains **NO**.