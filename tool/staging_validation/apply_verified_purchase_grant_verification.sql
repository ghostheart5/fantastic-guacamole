DO $chronospark_retired_staging$
BEGIN
  RAISE EXCEPTION 'Retired staging SQL: execution is disabled. Do not run this historical file against GhostHeart5 production.';
END
$chronospark_retired_staging$;

-- Read-only verification for the server-only apply_verified_purchase RPC grant contract.
select
  n.nspname as function_schema,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as argument_types,
  p.prosecdef as security_definer,
  coalesce(
    (
      select setting
      from unnest(coalesce(p.proconfig, array[]::text[])) as config(setting)
      where config.setting like 'search_path=%'
      limit 1
    ),
    '<default>'
  ) as search_path,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_has_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_has_execute,
  has_function_privilege('service_role', p.oid, 'EXECUTE') as service_role_has_execute,
  coalesce(
    (
      select string_agg(
        coalesce(grantee.rolname, 'PUBLIC') || ':' || acl.privilege_type,
        ', ' order by coalesce(grantee.rolname, 'PUBLIC'), acl.privilege_type
      )
      from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as acl
      left join pg_roles as grantee on grantee.oid = acl.grantee
      where acl.privilege_type = 'EXECUTE'
    ),
    '<none>'
  ) as execute_grants
from pg_proc as p
join pg_namespace as n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'apply_verified_purchase'
  and pg_get_function_identity_arguments(p.oid) =
    'target_user_id uuid, product_id text, purchase_type text, purchase_token_hash text, order_id text, verified_at timestamp with time zone, expires_at timestamp with time zone, payload jsonb';

-- Expected after hardening: anon_has_execute = false,
-- authenticated_has_execute = false, service_role_has_execute = true.
