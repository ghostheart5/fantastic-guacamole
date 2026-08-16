# Core-Sync Execution Approval

**Staging project:** `RETIRED_STAGING_PROJECT`

- [ ] Staging project confirmed
- [ ] User A confirmed
- [ ] User B confirmed
- [ ] Payload mappings reviewed
- [ ] Cleanup strategy reviewed
- [ ] No production URLs
- [ ] Explicit approval to execute mutation tests

## Execution Gate

**DO NOT RUN UNTIL ALL ITEMS ARE CHECKED.**

The generated runners require both `-ConfirmStaging` and `-ApproveMutationTests`. They accept only the configured staging URL, use the publishable/anon key and normal user sessions, and do not accept a service-role key.

## Cleanup Strategy

- Core-Sync rows use per-run GUID-derived identifiers and are deleted by the row owner after each case.
- A spoofed row that unexpectedly succeeds is removed by the actual owner session, allowing a security failure to be recorded without leaving test data behind.
- `settings` runs only when both users have no existing `id = 'default'` row; otherwise it skips rather than risk an existing setting.
- Profile probes restore the original caller-owned `full_name` after each attempted cross-user write.
- Monetization isolation suites issue no writes and therefore require no data cleanup.

## Not Covered

This approval does not authorize production activity, migrations, `db push`, `db reset`, data seeding, service-role use, Edge Function deployment, receipt validation, Storage operations, or direct `ai_proxy_rate_limits` access.
