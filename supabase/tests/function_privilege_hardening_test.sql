begin;
select plan(17);

-- All SECURITY DEFINER implementations must use a non-searchable namespace.
with expected(function_name, identity_arguments) as (
  values
    ('handle_new_user', ''),
    ('get_global_metrics', ''),
    ('ensure_profile_for_current_user', ''),
    ('consume_monetization_credits', 'credit_amount integer, reason text, metadata jsonb'),
    ('consume_ai_proxy_rate_limit', ''),
    ('consume_monetization_verify_rate_limit', '')
)
select ok(
  p.prosecdef
    and coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']::text[],
  format('public.%s(%s) is SECURITY DEFINER with an empty search_path', e.function_name, e.identity_arguments)
)
from expected e
join pg_proc p
  on p.proname = e.function_name
 and pg_get_function_identity_arguments(p.oid) = e.identity_arguments
join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public';

-- Exact Data API function allowlist. PUBLIC is represented by ACL grantee 0.
with expected(
  function_name,
  identity_arguments,
  authenticated_execute,
  service_role_execute,
  auth_admin_execute
) as (
  values
    ('handle_new_user', '', false, true, true),
    ('get_global_metrics', '', false, false, false),
    ('ensure_profile_for_current_user', '', true, false, false),
    ('consume_monetization_credits', 'credit_amount integer, reason text, metadata jsonb', true, false, false),
    ('consume_ai_proxy_rate_limit', '', true, false, false),
    ('consume_monetization_verify_rate_limit', '', true, false, false)
)
select ok(
  not has_function_privilege('anon', p.oid, 'EXECUTE')
    and has_function_privilege('authenticated', p.oid, 'EXECUTE') = e.authenticated_execute
    and has_function_privilege('service_role', p.oid, 'EXECUTE') = e.service_role_execute
    and has_function_privilege('supabase_auth_admin', p.oid, 'EXECUTE') = e.auth_admin_execute
    and not exists (
      select 1
      from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
      where acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
    ),
  format('public.%s(%s) has only its approved execution roles', e.function_name, e.identity_arguments)
)
from expected e
join pg_proc p
  on p.proname = e.function_name
 and pg_get_function_identity_arguments(p.oid) = e.identity_arguments
join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public';

-- Future postgres-owned public objects are not exposed automatically.
select ok(
  not exists (
    select 1
    from pg_default_acl d
    join pg_roles owner_role on owner_role.oid = d.defaclrole
    join pg_namespace n on n.oid = d.defaclnamespace
    cross join lateral aclexplode(d.defaclacl) acl
    left join pg_roles grantee_role on grantee_role.oid = acl.grantee
    where owner_role.rolname = 'postgres'
      and n.nspname = 'public'
      and d.defaclobjtype = 'r'
      and coalesce(grantee_role.rolname, 'PUBLIC') in ('anon', 'authenticated', 'service_role')
      and acl.privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
  ),
  'future public tables require explicit Data API grants'
);

select ok(
  not exists (
    select 1
    from pg_default_acl d
    join pg_roles owner_role on owner_role.oid = d.defaclrole
    join pg_namespace n on n.oid = d.defaclnamespace
    cross join lateral aclexplode(d.defaclacl) acl
    left join pg_roles grantee_role on grantee_role.oid = acl.grantee
    where owner_role.rolname = 'postgres'
      and n.nspname = 'public'
      and d.defaclobjtype = 'f'
      and coalesce(grantee_role.rolname, 'PUBLIC') in ('PUBLIC', 'anon', 'authenticated', 'service_role')
      and acl.privilege_type = 'EXECUTE'
  ),
  'future public functions require explicit Data API grants'
);

select ok(
  not exists (
    select 1
    from pg_default_acl d
    join pg_roles owner_role on owner_role.oid = d.defaclrole
    join pg_namespace n on n.oid = d.defaclnamespace
    cross join lateral aclexplode(d.defaclacl) acl
    left join pg_roles grantee_role on grantee_role.oid = acl.grantee
    where owner_role.rolname = 'postgres'
      and n.nspname = 'public'
      and d.defaclobjtype = 'S'
      and coalesce(grantee_role.rolname, 'PUBLIC') in ('anon', 'authenticated', 'service_role')
      and acl.privilege_type in ('USAGE', 'SELECT')
  ),
  'future public sequences require explicit Data API grants'
);

select ok(
  has_table_privilege('service_role', 'public.purchase_bindings', 'SELECT')
    and has_table_privilege('service_role', 'public.purchase_bindings', 'INSERT')
    and not has_table_privilege('service_role', 'public.purchase_bindings', 'UPDATE')
    and not has_table_privilege('service_role', 'public.purchase_bindings', 'DELETE'),
  'receipt binding storage exposes only SELECT and INSERT to service_role'
);

select ok(
  (
    select bool_and(
      has_table_privilege('service_role', format('public.%I', table_name), 'SELECT')
      and has_table_privilege('service_role', format('public.%I', table_name), 'INSERT')
      and has_table_privilege('service_role', format('public.%I', table_name), 'UPDATE')
      and has_table_privilege('service_role', format('public.%I', table_name), 'DELETE')
    )
    from unnest(array[
      'monetization_subscription_statuses',
      'monetization_wallets',
      'monetization_credit_transactions',
      'monetization_purchases',
      'monetization_entitlement_events'
    ]) table_name
  ),
  'server-side monetization tables have explicit service_role DML grants'
);

select * from finish();
rollback;
