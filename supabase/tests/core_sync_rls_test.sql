begin;
select plan(6);

insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000101', 'authenticated', 'authenticated', 'rls-one@example.test', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000102', 'authenticated', 'authenticated', 'rls-two@example.test', '{}'::jsonb, '{}'::jsonb, now(), now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000101', true);

insert into public.tasks (user_id, id, title)
values ('00000000-0000-0000-0000-000000000101', 'task-one', 'Owned task');
insert into public.settings (user_id, id)
values ('00000000-0000-0000-0000-000000000101', 'default');

select throws_ok(
  $$insert into public.tasks (user_id, id, title) values ('00000000-0000-0000-0000-000000000102', 'task-two', 'Cross-user task')$$,
  'new row violates row-level security policy for table "tasks"',
  'user one cannot insert a task for user two'
);
select is(
  (select count(*) from public.tasks where user_id = '00000000-0000-0000-0000-000000000102'),
  0::bigint,
  'user one cannot read user two tasks'
);
select is(
  (select count(*) from public.tasks where user_id = '00000000-0000-0000-0000-000000000102' and title = 'Tampered'),
  0::bigint,
  'user one cannot update user two tasks'
);
select throws_ok(
  $$insert into public.settings (user_id, id) values ('00000000-0000-0000-0000-000000000102', 'default')$$,
  'new row violates row-level security policy for table "settings"',
  'shared default settings ID remains user-owned'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id) values ('chronospark-sync', '00000000-0000-0000-0000-000000000102/blocked.json', '00000000-0000-0000-0000-000000000102')$$,
  'new row violates row-level security policy for table "objects"',
  'storage cross-prefix upload is denied'
);
select pass('two-user RLS test setup completed');

select * from finish();
rollback;