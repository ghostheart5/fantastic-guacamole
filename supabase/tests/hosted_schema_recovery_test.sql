begin;
select plan(120);

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

with expected(table_name, column_name) as (
  values
    ('focus_sessions', 'linked_goal_id'),
    ('focus_sessions', 'linked_task_id'),
    ('goal_checkins', 'goal_id'),
    ('task_steps', 'task_id')
)
select ok(
  column_type.data_type = 'text',
  format(
    'public.%I.%I matches the canonical account-scoped identifier type',
    expected.table_name,
    expected.column_name
  )
)
from expected
join information_schema.columns column_type
  on column_type.table_schema = 'public'
 and column_type.table_name = expected.table_name
 and column_type.column_name = expected.column_name;

select is(
  (
    select data_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'habit entries'
      and column_name = 'habit_id'
  ),
  'text',
  'public."habit entries".habit_id matches the canonical habit identifier type'
);

with expected(policy_name, requires_using) as (
  values
    ('habit entries - insert habit belongs', false),
    ('habit entries - update habit belongs', true)
), policy_expressions as (
  select
    expected.policy_name,
    expected.requires_using,
    coalesce(pg_get_expr(source_policy.polwithcheck, source_policy.polrelid), '') as check_expression,
    coalesce(pg_get_expr(source_policy.polqual, source_policy.polrelid), '') as using_expression
  from expected
  join pg_policy source_policy
    on source_policy.polrelid = 'public."habit entries"'::regclass
   and source_policy.polname = expected.policy_name
)
select ok(
  position('"habit entries".habit_id' in check_expression) > 0
    and position('h.user_id' in check_expression) > 0
    and position('auth.uid()' in check_expression) > 0
    and (
      not requires_using
      or (
        position('"habit entries".habit_id' in using_expression) > 0
        and position('h.user_id' in using_expression) > 0
        and position('auth.uid()' in using_expression) > 0
      )
    ),
  format('%s keeps the linked habit and authenticated owner checks', policy_name)
)
from policy_expressions;

with expected(table_name, constraint_name, definition) as (
  values
    (
      'focus_sessions',
      'focus_sessions_linked_goal_id_fkey',
      'FOREIGN KEY (user_id, linked_goal_id) REFERENCES goals(user_id, id) ON DELETE SET NULL (linked_goal_id)'
    ),
    (
      'focus_sessions',
      'focus_sessions_linked_task_id_fkey',
      'FOREIGN KEY (user_id, linked_task_id) REFERENCES tasks(user_id, id) ON DELETE SET NULL (linked_task_id)'
    ),
    (
      'goal_checkins',
      'goal_checkins_goal_id_fkey',
      'FOREIGN KEY (user_id, goal_id) REFERENCES goals(user_id, id) ON DELETE CASCADE'
    ),
    (
      'task_steps',
      'task_steps_task_id_fkey',
      'FOREIGN KEY (user_id, task_id) REFERENCES tasks(user_id, id) ON DELETE CASCADE'
    )
)
select is(
  pg_get_constraintdef(source_constraint.oid),
  expected.definition,
  format('%s preserves account ownership in its foreign key', expected.constraint_name)
)
from expected
join pg_constraint source_constraint
  on source_constraint.conrelid = format('public.%I', expected.table_name)::regclass
 and source_constraint.conname = expected.constraint_name;

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
