DO $chronospark_retired_staging$
BEGIN
  RAISE EXCEPTION 'Retired staging SQL: execution is disabled. Do not run this historical file against GhostHeart5 production.';
END
$chronospark_retired_staging$;

-- Read-only staging catalog and count audit. It does not create, alter, grant, revoke, or change data.
with non_system_schemas as (
  select oid, nspname
  from pg_namespace
  where nspname not in ('pg_catalog', 'information_schema')
    and nspname not like 'pg_toast%'
    and nspname not like 'pg_temp_%'
),
audit_rows as (
  select
    cast('schema' as text) as object_type,
    namespaces.nspname as schema_name,
    namespaces.nspname as object_name,
    cast(null as text) as details
  from non_system_schemas namespaces

  union all

  select
    cast('table' as text),
    namespaces.nspname,
    classes.relname,
    case when classes.relkind = 'p' then 'partitioned table' else 'table' end
  from pg_class classes
  join non_system_schemas namespaces on namespaces.oid = classes.relnamespace
  where classes.relkind in ('r', 'p')

  union all

  select
    cast('view' as text),
    namespaces.nspname,
    classes.relname,
    case when classes.relkind = 'm' then 'materialized view' else 'view' end
  from pg_class classes
  join non_system_schemas namespaces on namespaces.oid = classes.relnamespace
  where classes.relkind in ('v', 'm')

  union all

  select
    cast('function' as text),
    namespaces.nspname,
    procedures.proname,
    pg_get_function_identity_arguments(procedures.oid)
  from pg_proc procedures
  join non_system_schemas namespaces on namespaces.oid = procedures.pronamespace
  where procedures.prokind = 'f'

  union all

  select
    cast('trigger' as text),
    namespaces.nspname,
    triggers.tgname,
    classes.relname
  from pg_trigger triggers
  join pg_class classes on classes.oid = triggers.tgrelid
  join non_system_schemas namespaces on namespaces.oid = classes.relnamespace
  where triggers.tgisinternal = false

  union all

  select
    cast('policy' as text),
    namespaces.nspname,
    policies.polname,
    classes.relname
  from pg_policy policies
  join pg_class classes on classes.oid = policies.polrelid
  join non_system_schemas namespaces on namespaces.oid = classes.relnamespace

  union all

  select
    cast('extension' as text),
    extension_namespace.nspname,
    extensions.extname,
    extensions.extversion
  from pg_extension extensions
  join pg_namespace extension_namespace on extension_namespace.oid = extensions.extnamespace

  union all

  select
    cast('auth_user_count' as text),
    cast('auth' as text),
    cast('users' as text),
    cast(count(*) as text)
  from auth.users

  union all

  select
    cast('storage_bucket_count' as text),
    cast('storage' as text),
    cast('buckets' as text),
    cast(count(*) as text)
  from storage.buckets

  union all

  select
    cast('storage_object_count' as text),
    cast('storage' as text),
    cast('objects' as text),
    cast(count(*) as text)
  from storage.objects
)
select object_type, schema_name, object_name, details
from audit_rows
order by object_type, schema_name, object_name;
