begin;

create extension if not exists pgtap with schema extensions;
select plan(11);

select ok(
  not exists (
    select 1
    from pg_class target
    cross join lateral aclexplode(
      coalesce(target.relacl, acldefault('r', target.relowner))
    ) privilege
    where target.oid = 'public.ai_content_reports'::regclass
      and privilege.grantee = 0
      and privilege.privilege_type = 'INSERT'
  ),
  'PUBLIC cannot insert AI reports'
);
select ok(
  not has_table_privilege('anon', 'public.ai_content_reports', 'INSERT'),
  'anonymous clients cannot insert AI reports'
);
select ok(
  not has_table_privilege('authenticated', 'public.ai_content_reports', 'INSERT'),
  'authenticated clients cannot insert AI reports directly'
);
select ok(
  has_table_privilege('service_role', 'public.ai_content_reports', 'INSERT'),
  'only the server role can insert AI reports'
);
select ok(
  has_sequence_privilege(
    'service_role',
    pg_get_serial_sequence('public.ai_content_reports', 'id'),
    'USAGE'
  ),
  'the server role can allocate an AI report identity'
);
select ok(
  not has_sequence_privilege(
    'authenticated',
    pg_get_serial_sequence('public.ai_content_reports', 'id'),
    'USAGE'
  ),
  'authenticated clients cannot allocate AI report identities'
);

select is(
  (select file_size_limit from storage.buckets where id = 'chronospark-sync'),
  5242880::bigint,
  'legacy sync objects are capped at five MiB'
);
select results_eq(
  $$
    select unnest(allowed_mime_types)
    from storage.buckets
    where id = 'chronospark-sync'
  $$,
  array['application/json'::text],
  'legacy sync objects accept JSON only'
);
select results_eq(
  $$
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'chronospark_sync_select_own',
        'chronospark_sync_insert_own',
        'chronospark_sync_update_own',
        'chronospark_sync_delete_own'
      )
      and coalesce(qual, with_check, '') like '%full_backup.json%'
      and coalesce(qual, with_check, '') like '%tasks_backup.json%'
  $$,
  array[4::bigint],
  'every legacy sync policy is restricted to the two supported objects'
);
select results_eq(
  $$
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'chronospark_sync_insert_own',
        'chronospark_sync_update_own'
      )
      and coalesce(with_check, '') like '%account_deletion_in_progress%'
  $$,
  array[2::bigint],
  'legacy object writes consult deletion tombstones'
);
select results_eq(
  $$
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'cloud_backup_snapshots'
      and policyname in (
        'cloud_backup_snapshots_insert_own',
        'cloud_backup_snapshots_update_own'
      )
      and coalesce(with_check, '') like '%account_deletion_in_progress%'
  $$,
  array[2::bigint],
  'CAS writes consult deletion tombstones'
);

select * from finish();
rollback;
