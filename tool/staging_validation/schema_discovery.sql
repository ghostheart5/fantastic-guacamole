-- Read-only catalog inspection. This query does not create, change, or seed data.
with expected_tables(table_name) as (
  values
    ('profiles'), ('tasks'), ('goals'), ('habits'), ('settings'),
    ('purchase_bindings'), ('user_daily_metrics'), ('ai_proxy_rate_limits'),
    ('monetization_subscription_statuses'), ('monetization_wallets'),
    ('monetization_credit_transactions'), ('monetization_purchases'),
    ('monetization_entitlement_events')
),
non_system_schemas as (
  select oid, nspname
  from pg_namespace
  where nspname not in ('pg_catalog', 'information_schema')
    and nspname not like 'pg_toast%'
    and nspname not like 'pg_temp_%'
),
table_matches as (
  select
    expected_tables.table_name as expected_table_name,
    namespaces.nspname as schema_name,
    classes.oid as relation_id,
    classes.relrowsecurity as rls_enabled
  from expected_tables
  cross join non_system_schemas namespaces
  left join pg_class classes
    on classes.relnamespace = namespaces.oid
    and classes.relname = expected_tables.table_name
    and classes.relkind in ('r', 'p')
),
policy_summary as (
  select
    policies.polrelid as relation_id,
    count(*) as policy_count,
    bool_or(
      coalesce(pg_get_expr(policies.polqual, policies.polrelid), '') ilike '%auth.uid%' or
      coalesce(pg_get_expr(policies.polwithcheck, policies.polrelid), '') ilike '%auth.uid%'
    ) as auth_uid_policy_detected
  from pg_policy policies
  group by policies.polrelid
)
select
  table_matches.schema_name,
  table_matches.expected_table_name as table_name,
  true as table_exists,
  (user_column.attname is not null) as has_user_id,
  case when user_column.attname is not null
    then format_type(user_column.atttypid, user_column.atttypmod)
  end as user_id_type,
  table_matches.rls_enabled,
  coalesce(policy_summary.policy_count, 0)::bigint as policy_count,
  coalesce(policy_summary.auth_uid_policy_detected, false) as auth_uid_policy_detected
from table_matches
left join pg_attribute user_column
  on user_column.attrelid = table_matches.relation_id
  and user_column.attname = 'user_id'
  and user_column.attnum > 0
  and not user_column.attisdropped
left join policy_summary on policy_summary.relation_id = table_matches.relation_id
where table_matches.relation_id is not null
union all
select
  'NOT_FOUND' as schema_name,
  expected_tables.table_name,
  false as table_exists,
  false as has_user_id,
  null::text as user_id_type,
  null::boolean as rls_enabled,
  0::bigint as policy_count,
  false as auth_uid_policy_detected
from expected_tables
where not exists (
  select 1
  from table_matches
  where table_matches.expected_table_name = expected_tables.table_name
    and table_matches.relation_id is not null
)
order by table_name, table_exists desc, schema_name;