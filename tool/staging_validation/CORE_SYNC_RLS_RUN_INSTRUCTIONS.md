# Core-Sync RLS Run Instructions

**Execution status: NOT APPROVED. Production release status: NO.**

## Pre-Run Checklist

- [ ] The target project is staging ref `RETIRED_STAGING_PROJECT`.
- [ ] The target is not production.
- [ ] User A and User B are staging-only users.
- [ ] `.env` contains only staging credentials.
- [ ] The cleanup strategy has been reviewed.
- [ ] Mutation testing has been explicitly approved.
- [ ] Production release remains blocked.

## Approval Marker

The guarded runner requires the local approval marker `tool/staging_validation/.core_sync_rls_approved` in addition to `-ConfirmStaging`.

After every pre-run item is checked, a human must create the empty marker locally:

```powershell
New-Item -ItemType File .\tool\staging_validation\.core_sync_rls_approved
```

The marker is ignored by Git and must not be committed. Do not create it before approval.

## Approved Execution Command

Run only after the checklist is complete and the local marker exists:

```powershell
.\tool\staging_validation\run_core_sync_rls_checks.ps1 -ConfirmStaging
```

## Expected Behavior

- User A own-row operations pass for Core-Sync tables.
- User B cross-user reads, updates, and deletes are denied or affect zero rows.
- Spoofed `user_id` writes are denied or create zero rows.
- Profiles use `id = auth.uid()`; no profile test assumes `user_id`.
- Monetization isolation tests query only and contain no direct writes.

## Failure Interpretation

- Unexpected cross-user access is a security bug.
- Unexpected spoofed write success is a security bug.
- Cleanup failure requires manual review before another run.
- Do not weaken RLS to make a test pass.
- Stop the investigation on the confirmed staging environment; do not reroute the runner to production.
