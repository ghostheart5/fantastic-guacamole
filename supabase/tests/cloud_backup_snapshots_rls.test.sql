begin;

create extension if not exists pgtap with schema extensions;
select plan(13);

select has_table(
  'public',
  'cloud_backup_snapshots',
  'cloud backup CAS table exists'
);

insert into auth.users (id, email)
values
  ('11111111-1111-4111-8111-111111111111', 'backup-a@example.invalid'),
  ('22222222-2222-4222-8222-222222222222', 'backup-b@example.invalid');

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select lives_ok(
  $$
    insert into public.cloud_backup_snapshots (user_id, revision, payload)
    values (
      '11111111-1111-4111-8111-111111111111',
      1,
      '{"version":"3.0.0","tasks":[]}'::jsonb
    )
  $$,
  'owner creates revision one'
);

select results_eq(
  $$select revision from public.cloud_backup_snapshots$$,
  array[1::bigint],
  'owner reads the current revision'
);

select lives_ok(
  $$
    update public.cloud_backup_snapshots
    set revision = 2,
        payload = '{"version":"3.0.0","tasks":[{"id":"a"}]}'::jsonb
    where user_id = '11111111-1111-4111-8111-111111111111'
      and revision = 1
  $$,
  'matching revision advances exactly once'
);

select results_eq(
  $$select revision from public.cloud_backup_snapshots$$,
  array[2::bigint],
  'successful compare-and-swap stores the next revision'
);

select results_eq(
  $$
    update public.cloud_backup_snapshots
    set revision = 2,
        payload = '{"version":"3.0.0","tasks":[{"id":"stale"}]}'::jsonb
    where user_id = '11111111-1111-4111-8111-111111111111'
      and revision = 1
    returning revision
  $$,
  array[]::bigint[],
  'a stale compare-and-swap changes no row'
);

select throws_ok(
  $$
    update public.cloud_backup_snapshots
    set revision = 4
    where user_id = '11111111-1111-4111-8111-111111111111'
  $$,
  'P0001',
  'cloud backup revision conflict',
  'revision jumps are rejected'
);

select throws_ok(
  $$
    insert into public.cloud_backup_snapshots (user_id, revision, payload)
    values (
      '22222222-2222-4222-8222-222222222222',
      1,
      '{"version":"3.0.0"}'::jsonb
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "cloud_backup_snapshots"',
  'cross-account insertion is rejected'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select results_eq(
  'select count(*) from public.cloud_backup_snapshots',
  array[0::bigint],
  'another account cannot read the owner snapshot'
);

select results_eq(
  $$
    update public.cloud_backup_snapshots
    set revision = 3
    where user_id = '11111111-1111-4111-8111-111111111111'
    returning revision
  $$,
  array[]::bigint[],
  'another account cannot update the owner snapshot'
);

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select throws_ok(
  $$
    update public.cloud_backup_snapshots
    set user_id = '22222222-2222-4222-8222-222222222222',
        revision = 3
    where user_id = '11111111-1111-4111-8111-111111111111'
  $$,
  'P0001',
  'cloud backup owner is immutable',
  'snapshot ownership cannot be reassigned'
);

set local role anon;
select throws_ok(
  $$select count(*) from public.cloud_backup_snapshots$$,
  '42501',
  'permission denied for table cloud_backup_snapshots',
  'anonymous reads are denied at the privilege boundary'
);

reset role;
delete from auth.users
where id = '11111111-1111-4111-8111-111111111111';
select results_eq(
  $$
    select count(*)
    from public.cloud_backup_snapshots
    where user_id = '11111111-1111-4111-8111-111111111111'
  $$,
  array[0::bigint],
  'account deletion cascades cloud backup snapshots'
);

select * from finish();
rollback;
