begin;
select plan(109);

with expected(table_name) as (
  values
    ('achievements'),
    ('admin_users'),
    ('app_announcements'),
    ('app_events'),
    ('core_values'),
    ('entitlement_events'),
    ('feedback_reports'),
    ('focus_sessions'),
    ('goal_checkins'),
    ('habit entries'),
    ('memoryEngine'),
    ('milestones'),
    ('notifications'),
    ('recurring_rules'),
    ('smart coach notes'),
    ('soul_maps'),
    ('streaks'),
    ('subscriptions'),
    ('sync_queue'),
    ('task_steps'),
    ('timeline_events'),
    ('user_achievements'),
    ('user_devices'),
    ('webhook_events')
)
select has_table(
  'public',
  table_name,
  format('public.%I is reproducible from local migrations', table_name)
)
from expected;

with expected(table_name) as (
  values
    ('achievements'), ('admin_users'), ('app_announcements'), ('app_events'),
    ('core_values'), ('entitlement_events'), ('feedback_reports'),
    ('focus_sessions'), ('goal_checkins'), ('habit entries'), ('memoryEngine'),
    ('milestones'), ('notifications'), ('recurring_rules'),
    ('smart coach notes'), ('soul_maps'), ('streaks'), ('subscriptions'),
    ('sync_queue'), ('task_steps'), ('timeline_events'),
    ('user_achievements'), ('user_devices'), ('webhook_events')
)
select ok(
  source_table.relrowsecurity,
  format('public.%I has row-level security enabled', expected.table_name)
)
from expected
join pg_class source_table on source_table.relname = expected.table_name
join pg_namespace source_schema
  on source_schema.oid = source_table.relnamespace
 and source_schema.nspname = 'public';

with expected(table_name) as (
  values
    ('achievements'), ('admin_users'), ('app_announcements'), ('app_events'),
    ('core_values'), ('entitlement_events'), ('feedback_reports'),
    ('focus_sessions'), ('goal_checkins'), ('habit entries'), ('memoryEngine'),
    ('milestones'), ('notifications'), ('recurring_rules'),
    ('smart coach notes'), ('soul_maps'), ('streaks'), ('subscriptions'),
    ('sync_queue'), ('task_steps'), ('timeline_events'),
    ('user_achievements'), ('user_devices'), ('webhook_events')
)
select ok(
  not has_table_privilege('anon', format('public.%I', table_name), 'SELECT')
    and not has_table_privilege('anon', format('public.%I', table_name), 'INSERT')
    and not has_table_privilege('anon', format('public.%I', table_name), 'UPDATE')
    and not has_table_privilege('anon', format('public.%I', table_name), 'DELETE'),
  format('anon has no DML privileges on public.%I', table_name)
)
from expected;

with expected(table_name) as (
  values
    ('achievements'), ('admin_users'), ('app_announcements'), ('app_events'),
    ('core_values'), ('entitlement_events'), ('feedback_reports'),
    ('focus_sessions'), ('goal_checkins'), ('habit entries'), ('memoryEngine'),
    ('milestones'), ('notifications'), ('recurring_rules'),
    ('smart coach notes'), ('soul_maps'), ('streaks'), ('subscriptions'),
    ('sync_queue'), ('task_steps'), ('timeline_events'),
    ('user_achievements'), ('user_devices'), ('webhook_events')
)
select ok(
  not has_table_privilege('service_role', format('public.%I', table_name), 'TRUNCATE')
    and not has_table_privilege('service_role', format('public.%I', table_name), 'TRIGGER')
    and not has_table_privilege('service_role', format('public.%I', table_name), 'REFERENCES')
    and not has_table_privilege('service_role', format('public.%I', table_name), 'MAINTAIN'),
  format('service_role has DML-only table privileges on public.%I', table_name)
)
from expected;

select ok(
  not exists (
    select 1
    from pg_policy policy
    where policy.polrelid = 'public.notifications'::regclass
      and 0 = any(policy.polroles)
  ),
  'notification ownership policies do not target PUBLIC'
);

select ok(
  not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.soul_maps'::regclass
      and tgname = 'trg_set_updated_at'
      and not tgisinternal
  ),
  'soul_maps has no duplicate legacy updated_at trigger'
);

select ok(
  not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.timeline_events'::regclass
      and tgname = 'trg_set_updated_at'
      and not tgisinternal
  ),
  'timeline_events has no duplicate legacy updated_at trigger'
);

select ok(
  not has_function_privilege('anon', 'public.set_updated_at()', 'EXECUTE')
    and not has_function_privilege('authenticated', 'public.set_updated_at()', 'EXECUTE')
    and not has_function_privilege('service_role', 'public.set_updated_at()', 'EXECUTE'),
  'set_updated_at is trigger-only'
);

select ok(
  not has_function_privilege('anon', 'public.sync_app_events_legacy_fields()', 'EXECUTE')
    and not has_function_privilege('authenticated', 'public.sync_app_events_legacy_fields()', 'EXECUTE')
    and not has_function_privilege('service_role', 'public.sync_app_events_legacy_fields()', 'EXECUTE'),
  'sync_app_events_legacy_fields is trigger-only'
);

with expected(table_name) as (
  values
    ('core_values'),
    ('habit entries'),
    ('memoryEngine'),
    ('milestones'),
    ('notifications'),
    ('smart coach notes'),
    ('soul_maps'),
    ('timeline_events')
)
select ok(
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = expected.table_name
  ),
  format('public.%I is in the Supabase Realtime publication', table_name)
)
from expected;

select * from finish();
rollback;
