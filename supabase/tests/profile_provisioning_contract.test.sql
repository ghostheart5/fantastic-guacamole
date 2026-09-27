begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'profiles'
     and column_name in ('email', 'full_name', 'avatar_url')
     and is_nullable = 'YES' and column_default is null),
  3::bigint,
  'optional profile metadata remains nullable without invented defaults'
);
select is(
  (select t.tgfoid from pg_trigger t
   where t.tgrelid = 'auth.users'::regclass
     and t.tgname = 'on_auth_user_created'),
  'public.handle_new_user()'::regprocedure::oid,
  'signup uses the reviewed hardened profile trigger'
);
select lives_ok(
  $$insert into auth.users (id, email) values
    ('61952700-0000-4000-8000-000000000001', 'profile-empty@example.invalid')$$,
  'signup succeeds without optional metadata'
);
select results_eq(
  $$select full_name, avatar_url from public.profiles
    where id = '61952700-0000-4000-8000-000000000001'$$,
  $$values (null::text, null::text)$$,
  'signup without metadata still creates its profile'
);
select lives_ok(
  $$insert into auth.users (id, email, raw_user_meta_data) values
    ('61952700-0000-4000-8000-000000000002', 'profile-named@example.invalid',
     '{"name":"Synthetic profile","avatar_url":"https://example.invalid/avatar"}'::jsonb)$$,
  'signup accepts ordinary provider display metadata'
);
select results_eq(
  $$select full_name, avatar_url from public.profiles
    where id = '61952700-0000-4000-8000-000000000002'$$,
  $$values ('Synthetic profile'::text, 'https://example.invalid/avatar'::text)$$,
  'provider display metadata is preserved'
);
set local role authenticated;
set local request.jwt.claim.sub = '61952700-0000-4000-8000-000000000001';
select results_eq(
  $$select id from public.profiles$$,
  array['61952700-0000-4000-8000-000000000001'::uuid],
  'owner can read only its own new profile'
);
select results_eq(
  $$select id from public.profiles
    where id = '61952700-0000-4000-8000-000000000002'$$,
  array[]::uuid[],
  'other profile remains isolated'
);
reset role;
select * from finish();
rollback;
