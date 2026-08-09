# Grant Credits Authorization Run Instructions

**Execution approval: NOT APPROVED. Production release status: NO.**

## Pre-Run Checklist

- [ ] The target is confirmed staging project `pxtjkwfedrtnxuihtdox`.
- [ ] The target URL is `https://pxtjkwfedrtnxuihtdox.supabase.co`, not a production project or a `/rest/v1/` endpoint.
- [ ] User A and User B are staging-only users.
- [ ] `.env` contains only the staging anon key and User A/User B credentials.
- [ ] The approval checklist in [GRANT_CREDITS_AUTHORIZATION_APPROVAL.md](GRANT_CREDITS_AUTHORIZATION_APPROVAL.md) is fully checked by a human.
- [ ] Production release remains blocked.

## Expected Denial Cases

- Anonymous caller cannot grant credits to User A.
- User A cannot grant credits to User A or User B.
- User B cannot grant credits to User B or User A.
- No client-visible wallet balance, bonus balance, or lifetime-earned value changes.
- No client-visible credit transaction row appears.

## Safety Constraints

- The runner uses only the staging anon key plus normal User A/User B sessions.
- It does not test privileged-role success or use a privileged credential path.
- It does not create harness-owned rows; expected denials require no cleanup.
- Do not point the runner at production or modify RLS to make a denial test pass.

## Manual Command

Run only after human approval:

```powershell
.\tool\staging_validation\run_grant_credit_authorization_checks.ps1 -ConfirmStaging
```

## Failure Interpretation

- A successful anonymous or authenticated grant call is a security defect.
- A visible wallet increase or new credit transaction after a denied call is a security defect requiring manual investigation.
- A missing expected denial may indicate unexpected function grants or authorization behavior; do not bypass or weaken controls to continue.
- Record the run in [GRANT_CREDITS_AUTHORIZATION_RESULTS.md](GRANT_CREDITS_AUTHORIZATION_RESULTS.md).

## Remaining Blockers After This Test

- Valid/insufficient debit setup and cleanup.
- Receipt mismatch / `apply_verified_purchase` validation.
- Storage policy-contract validation.
- Monetization own-record visibility pending naturally provisioned or approved isolated rows.

Production release status: **NO**.