-- Close remaining Phase 2 data-boundary gaps without enabling cloud features.

-- A lingering authenticated JWT must not recreate a CAS backup after account
-- deletion has entered the durable server-owned workflow.
drop policy if exists cloud_backup_snapshots_insert_own
  on public.cloud_backup_snapshots;
create policy cloud_backup_snapshots_insert_own
on public.cloud_backup_snapshots
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and not public.account_deletion_in_progress()
);

drop policy if exists cloud_backup_snapshots_update_own
  on public.cloud_backup_snapshots;
create policy cloud_backup_snapshots_update_own
on public.cloud_backup_snapshots
for update
to authenticated
using (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and not public.account_deletion_in_progress()
)
with check (
  (select auth.uid()) is not null
  and (select auth.uid()) = user_id
  and not public.account_deletion_in_progress()
);

-- The reporting Edge Function performs one return-minimal INSERT. Make that
-- capability explicit and remove every ambient client/default privilege.
revoke all on table public.ai_content_reports
  from public, anon, authenticated, service_role;
grant insert on table public.ai_content_reports to service_role;

do $$
declare
  report_sequence text;
begin
  report_sequence := pg_get_serial_sequence(
    'public.ai_content_reports',
    'id'
  );
  if report_sequence is null then
    raise exception 'ai_content_reports identity sequence is missing';
  end if;
  execute format(
    'revoke all on sequence %s from public, anon, authenticated, service_role',
    report_sequence
  );
  execute format(
    'grant usage on sequence %s to service_role',
    report_sequence
  );
end;
$$;

-- Legacy object backup remains disabled at the product boundary, but its
-- server policy still needs to be safe while migration/cleanup support exists.
update storage.buckets
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['application/json']::text[]
where id = 'chronospark-sync';

drop policy if exists "chronospark_sync_select_own" on storage.objects;
create policy "chronospark_sync_select_own"
on storage.objects for select to authenticated
using (
  bucket_id = 'chronospark-sync'
  and name in (
    (select auth.uid())::text || '/backup/full_backup.json',
    (select auth.uid())::text || '/backup/tasks_backup.json'
  )
);

drop policy if exists "chronospark_sync_insert_own" on storage.objects;
create policy "chronospark_sync_insert_own"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chronospark-sync'
  and name in (
    (select auth.uid())::text || '/backup/full_backup.json',
    (select auth.uid())::text || '/backup/tasks_backup.json'
  )
  and not public.account_deletion_in_progress()
);

drop policy if exists "chronospark_sync_update_own" on storage.objects;
create policy "chronospark_sync_update_own"
on storage.objects for update to authenticated
using (
  bucket_id = 'chronospark-sync'
  and name in (
    (select auth.uid())::text || '/backup/full_backup.json',
    (select auth.uid())::text || '/backup/tasks_backup.json'
  )
  and not public.account_deletion_in_progress()
)
with check (
  bucket_id = 'chronospark-sync'
  and name in (
    (select auth.uid())::text || '/backup/full_backup.json',
    (select auth.uid())::text || '/backup/tasks_backup.json'
  )
  and not public.account_deletion_in_progress()
);

drop policy if exists "chronospark_sync_delete_own" on storage.objects;
create policy "chronospark_sync_delete_own"
on storage.objects for delete to authenticated
using (
  bucket_id = 'chronospark-sync'
  and name in (
    (select auth.uid())::text || '/backup/full_backup.json',
    (select auth.uid())::text || '/backup/tasks_backup.json'
  )
);
