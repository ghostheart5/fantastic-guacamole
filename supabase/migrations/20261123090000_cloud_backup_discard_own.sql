-- Let a signed-in user discard their own encrypted cloud backup snapshot, so
-- a lost recovery key no longer blocks cloud backup for the account forever.
-- The app offers this only when the device cannot read the snapshot, behind
-- two confirmations, and deletes only at the revision it checked.
--
-- Scope: adds DELETE for the row owner only. The select, insert and update
-- policies and the revision trigger are unchanged.
--
-- Refused while an account deletion request exists (in progress or
-- completed tombstone), matching the insert and update policies from
-- 20260830050000_phase2_data_security_hardening.sql: from then on the
-- server-owned deletion workflow owns the row, and a lingering JWT must not
-- change it.

grant delete on table public.cloud_backup_snapshots to authenticated;

drop policy if exists cloud_backup_snapshots_delete_own
  on public.cloud_backup_snapshots;
create policy cloud_backup_snapshots_delete_own
on public.cloud_backup_snapshots
for delete
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and not public.account_deletion_in_progress()
);
