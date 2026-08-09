-- Read-only catalog inspection. This query does not create, change, or seed data.
with expected_functions(function_name) as (
  values
    ('handle_new_user'), ('ensure_profile_for_current_user'),
    ('get_global_metrics'), ('ensure_monetization_wallet'),
    ('reset_monetization_allowance'), ('grant_monetization_credits'),
    ('consume_monetization_credits'), ('apply_verified_purchase'),
    ('consume_ai_proxy_rate_limit')
),
function_matches as (
  select
    expected_functions.function_name as expected_function_name,
    namespaces.nspname as schema_name,
    procedures.oid as function_id,
    pg_get_function_identity_arguments(procedures.oid) as argument_types,
    procedures.prosecdef as security_definer,
    (
      select setting
      from unnest(coalesce(procedures.proconfig, array[]::text[])) setting
      where setting like 'search_path=%'
      limit 1
    ) as search_path_setting
  from expected_functions
  left join pg_proc procedures on procedures.proname = expected_functions.function_name
  left join pg_namespace namespaces on namespaces.oid = procedures.pronamespace
)
select
  coalesce(function_matches.schema_name, 'NOT_FOUND') as schema_name,
  function_matches.expected_function_name as function_name,
  function_matches.argument_types,
  coalesce(function_matches.security_definer, false) as security_definer,
  function_matches.search_path_setting,
  coalesce(string_agg(privileges.grantee || ':' || privileges.privilege_type, ', ' order by privileges.grantee), '') as execute_grants
from function_matches
left join information_schema.routine_privileges privileges
  on privileges.specific_schema = function_matches.schema_name
  and privileges.routine_name = function_matches.expected_function_name
  and privileges.privilege_type = 'EXECUTE'
group by
  function_matches.schema_name,
  function_matches.expected_function_name,
  function_matches.argument_types,
  function_matches.security_definer,
  function_matches.search_path_setting
order by function_name, argument_types nulls first, schema_name;