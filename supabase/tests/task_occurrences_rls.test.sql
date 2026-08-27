begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

select has_table('public', 'task_occurrences', 'task_occurrences exists');
select has_column(
  'public',
  'task_occurrences',
  'series_id',
  'task_occurrences has stable series identity'
);

insert into auth.users (id, email)
values
  ('11111111-1111-4111-8111-111111111111', 'occurrence-a@example.invalid'),
  ('22222222-2222-4222-8222-222222222222', 'occurrence-b@example.invalid');

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select lives_ok(
  $$
    insert into public.task_occurrences (
      user_id, id, series_id, task_id, occurrence_key, operation_id,
      outcome, resolved_at, created_at, updated_at
    ) values (
      '11111111-1111-4111-8111-111111111111',
      'row-a', 'series-a', 'task-a', 'slot-a', 'operation-a',
      'completed', now(), now(), now()
    )
  $$,
  'authenticated user inserts an owned immutable occurrence'
);

select results_eq(
  'select count(*) from public.task_occurrences',
  array[1::bigint],
  'authenticated user sees only owned occurrences'
);

select lives_ok(
  $$
    insert into public.task_occurrences (
      user_id, id, series_id, task_id, occurrence_key, operation_id,
      outcome, resolved_at, created_at, updated_at
    ) values (
      '11111111-1111-4111-8111-111111111111',
      'row-a', 'series-a', 'task-a', 'slot-a', 'operation-a',
      'completed', now(), now(), now()
    )
    on conflict (user_id, task_id, occurrence_key, operation_id) do nothing
  $$,
  'same operation replays idempotently'
);

select throws_ok(
  $$
    insert into public.task_occurrences (
      user_id, id, series_id, task_id, occurrence_key, operation_id,
      outcome, resolved_at, created_at, updated_at
    ) values (
      '22222222-2222-4222-8222-222222222222',
      'cross-account-row', 'series-b', 'task-b', 'slot-b', 'operation-b',
      'completed', now(), now(), now()
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "task_occurrences"',
  'cross-account insertion is rejected'
);

select throws_ok(
  $$update public.task_occurrences set outcome = 'skipped' where id = 'row-a'$$,
  'P0001',
  'task occurrences are immutable',
  'an acknowledged transition cannot be mutated'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select results_eq(
  'select count(*) from public.task_occurrences',
  array[0::bigint],
  'second account cannot read first account occurrences'
);

set local role anon;
select throws_ok(
  $$select count(*) from public.task_occurrences$$,
  '42501',
  'permission denied for table task_occurrences',
  'anonymous access is denied at the privilege boundary'
);

reset role;
delete from auth.users
where id = '11111111-1111-4111-8111-111111111111';
select results_eq(
  $$
    select count(*)
    from public.task_occurrences
    where user_id = '11111111-1111-4111-8111-111111111111'
  $$,
  array[0::bigint],
  'account deletion cascades occurrence rows'
);

select * from finish();
rollback;
