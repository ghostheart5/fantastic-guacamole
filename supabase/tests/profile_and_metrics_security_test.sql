begin;
select plan(4);

select has_function('public', 'ensure_profile_for_current_user', 'profile repair RPC exists');
select ok(
  (
    select p.prosecdef
      and coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'ensure_profile_for_current_user'
      and pg_get_function_identity_arguments(p.oid) = ''
  ),
  'profile repair is security definer with an empty search path'
);
select ok(
  exists (
    select 1
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    join pg_namespace pn on pn.oid = p.pronamespace
    where not t.tgisinternal
      and n.nspname = 'auth'
      and c.relname = 'users'
      and t.tgname = 'on_auth_user_created'
      and pn.nspname = 'public'
      and p.proname = 'handle_new_user'
  ),
  'auth user creation is connected to the hardened profile trigger'
);
select ok(
  not has_function_privilege('PUBLIC', 'public.get_global_metrics()', 'EXECUTE')
    and not has_function_privilege('anon', 'public.get_global_metrics()', 'EXECUTE')
    and not has_function_privilege('authenticated', 'public.get_global_metrics()', 'EXECUTE'),
  'public, anonymous, and normal authenticated callers cannot execute global metrics'
);

select * from finish();
rollback;
