begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email)
values
  ('33333333-3333-4333-8333-333333333333', 'discard-a@example.invalid'),
  ('44444444-4444-4444-8444-444444444444', 'discard-b@example.invalid');

insert into public.cloud_backup_snapshots (user_id, revision, payload)
values
  ('33333333-3333-4333-8333-333333333333', 1, '{"format":"x"}'::jsonb),
  ('44444444-4444-4444-8444-444444444444', 1, '{"format":"y"}'::jsonb);

select ok(
  has_table_privilege('authenticated', 'public.cloud_backup_snapshots', 'DELETE'),
  'signed-in clients hold the delete privilege'
);

select ok(
  not has_table_privilege('anon', 'public.cloud_backup_snapshots', 'DELETE'),
  'anonymous clients cannot delete snapshots'
);

select results_eq(
  $$
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'cloud_backup_snapshots'
      and policyname in (
        'cloud_backup_snapshots_select_own',
        'cloud_backup_snapshots_insert_own',
        'cloud_backup_snapshots_update_own'
      )
      and (
        (policyname = 'cloud_backup_snapshots_select_own' and cmd = 'SELECT')
        or (
          policyname in (
            'cloud_backup_snapshots_insert_own',
            'cloud_backup_snapshots_update_own'
          )
          and coalesce(with_check, '') like '%account_deletion_in_progress%'
        )
      )
  $$,
  array[3::bigint],
  'select, insert and update policies are unchanged'
);

select results_eq(
  $$
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'cloud_backup_snapshots'
      and policyname = 'cloud_backup_snapshots_delete_own'
      and cmd = 'DELETE'
      and roles = array['authenticated']::name[]
      and coalesce(qual, '') like '%auth.uid()%'
      and coalesce(qual, '') like '%account_deletion_in_progress%'
  $$,
  array[1::bigint],
  'the delete policy checks the owner and the deletion tombstone'
);

set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-8444-444444444444';

select results_eq(
  $$
    delete from public.cloud_backup_snapshots
    where user_id = '33333333-3333-4333-8333-333333333333'
    returning revision
  $$,
  array[]::bigint[],
  'another account cannot delete the owner snapshot'
);

set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';

select results_eq(
  $$
    delete from public.cloud_backup_snapshots
    where user_id = '33333333-3333-4333-8333-333333333333'
      and revision = 2
    returning revision
  $$,
  array[]::bigint[],
  'a delete at a stale revision removes nothing'
);

select results_eq(
  $$
    delete from public.cloud_backup_snapshots
    where user_id = '33333333-3333-4333-8333-333333333333'
      and revision = 1
    returning revision
  $$,
  array[1::bigint],
  'the owner can discard their own snapshot'
);

select lives_ok(
  $$
    insert into public.cloud_backup_snapshots (user_id, revision, payload)
    values (
      '33333333-3333-4333-8333-333333333333',
      1,
      '{"format":"new"}'::jsonb
    )
  $$,
  'after a discard the owner starts again at revision one'
);

reset role;
select results_eq(
  $$
    select count(*)
    from public.cloud_backup_snapshots
    where user_id = '44444444-4444-4444-8444-444444444444'
  $$,
  array[1::bigint],
  'the other account snapshot is untouched'
);

insert into public.account_deletion_requests (
  request_id,
  user_id,
  receipt_hash,
  state
) values (
  repeat('a', 64),
  '33333333-3333-4333-8333-333333333333',
  repeat('b', 64),
  'requested'
);

set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';

select results_eq(
  $$
    delete from public.cloud_backup_snapshots
    where user_id = '33333333-3333-4333-8333-333333333333'
    returning revision
  $$,
  array[]::bigint[],
  'a deletion tombstone blocks discarding from a lingering JWT'
);

select * from finish();
rollback;
