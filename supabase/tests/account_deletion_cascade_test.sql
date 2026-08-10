begin;
select plan(24);

with expected(table_name) as (
  values
    ('app_events'),
    ('core_values'),
    ('goals'),
    ('habit entries'),
    ('milestones'),
    ('notifications'),
    ('settings'),
    ('smart coach notes'),
    ('soul_maps'),
    ('tasks'),
    ('timeline_events'),
    ('webhook_events')
)
select ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class source_table on source_table.oid = c.conrelid
    join pg_namespace source_schema on source_schema.oid = source_table.relnamespace
    join pg_class target_table on target_table.oid = c.confrelid
    join pg_namespace target_schema on target_schema.oid = target_table.relnamespace
    join unnest(c.conkey) key(attnum) on true
    join pg_attribute source_column
      on source_column.attrelid = source_table.oid
     and source_column.attnum = key.attnum
    where c.contype = 'f'
      and c.confdeltype = 'c'
      and source_schema.nspname = 'public'
      and source_table.relname = expected.table_name
      and source_column.attname = 'user_id'
      and target_schema.nspname = 'auth'
      and target_table.relname = 'users'
  ),
  format('public.%I.user_id cascades when the Auth user is deleted', expected.table_name)
)
from expected;

with expected(table_name) as (
  values
    ('app_events'),
    ('core_values'),
    ('goals'),
    ('habit entries'),
    ('milestones'),
    ('notifications'),
    ('settings'),
    ('smart coach notes'),
    ('soul_maps'),
    ('tasks'),
    ('timeline_events'),
    ('webhook_events')
)
select ok(
  exists (
    select 1
    from pg_class source_table
    join pg_namespace source_schema
      on source_schema.oid = source_table.relnamespace
     and source_schema.nspname = 'public'
    join pg_attribute user_column
      on user_column.attrelid = source_table.oid
     and user_column.attname = 'user_id'
    join pg_index source_index
      on source_index.indrelid = source_table.oid
     and source_index.indisvalid
     and (source_index.indkey::smallint[])[0] = user_column.attnum
    where source_table.relname = expected.table_name
  ),
  format('public.%I.user_id has a leading cascade index', expected.table_name)
)
from expected;

select * from finish();
rollback;
