# Core-Sync RLS Final Execution Approval

**Confirmed staging project:** `pxtjkwfedrtnxuihtdox`

- [ ] I confirm `pxtjkwfedrtnxuihtdox` is staging.
- [ ] I confirm this is not production.
- [ ] I confirm User A and User B are staging-only users.
- [ ] I confirm `.env` contains only staging credentials.
- [ ] I confirm cleanup strategy is acceptable.
- [ ] I confirm settings skip behavior is acceptable.
- [ ] I understand these tests will insert/update/delete staging test rows.
- [ ] I understand these tests must not run against production.
- [ ] I approve execution of Core-Sync RLS mutation tests against staging only.

## Status

Until every checkbox is checked, execution status must remain: **NOT APPROVED**.

After all checks are complete, a human must manually create the ignored local marker `.core_sync_rls_approved` in this directory. The marker is intentionally not created by automation and is required in addition to `-ConfirmStaging`.

Production release status: **NO**.