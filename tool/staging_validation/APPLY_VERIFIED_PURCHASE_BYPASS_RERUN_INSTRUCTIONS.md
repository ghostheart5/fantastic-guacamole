# Apply Verified Purchase Bypass Rerun Instructions

Run this only after approved staging grant verification shows the required server-only grant state. Do not run it against production.

## Prerequisites

1. Confirm the target is `https://pxtjkwfedrtnxuihtdox.supabase.co`.
2. Complete the grant re-verification procedure.
3. Confirm `anon_has_execute = false`, `authenticated_has_execute = false`, and `service_role_has_execute = true`.
4. Do not add a service-role key to the client-side staging environment or runner.

## Capture Complete Output

Run from the `tool` directory and preserve the output file with the execution record:

```powershell
.\staging_validation\run_apply_verified_purchase_bypass_checks.ps1 -ConfirmStaging *> .\staging_validation\apply_verified_purchase_bypass_rerun_output.txt
$exitCode = $LASTEXITCODE
Add-Content -LiteralPath .\staging_validation\apply_verified_purchase_bypass_rerun_output.txt -Value "Process exit status: $exitCode"
```

If the process execution policy blocks the script, run this process-scoped command, then repeat the captured rerun command:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Required Captured Evidence

The output file must contain:

1. The target URL.
2. Every PASS, FAIL, and SKIP assertion.
3. Final summary counts.
4. Anonymous direct-call denial.
5. User A direct-call denial for User A.
6. User A direct-call denial for User B.
7. User B direct-call denial for User B.
8. User B direct-call denial for User A.
9. No purchase rows created.
10. No entitlement events created.
11. No wallet state changed.
12. Process exit status.

Copy the output-file path and summary counts into `APPLY_VERIFIED_PURCHASE_BYPASS_RESULTS.md`. Do not treat the receipt hardening as complete until the captured evidence and grant output are reviewed.

Production release remains **NO**.