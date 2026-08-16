begin;
select plan(12);

with expected(table_name, policy_name, require_using, require_check) as (
  values
    ('milestones', 'milestones_select_own', true, false),
    ('milestones', 'milestones_insert_own', false, true),
    ('milestones', 'milestones_update_own', true, true),
    ('milestones', 'milestones_delete_own', true, false),
    ('memoryEngine', 'memoryEngine_select_own', true, false),
    ('memoryEngine', 'memoryengine_insert_own', false, true),
    ('memoryEngine', 'memoryengine_update_own', true, true),
    ('memoryEngine', 'memoryengine_delete_own', true, false),
    ('user_daily_metrics', 'user_daily_metrics_select_own', true, false),
    ('user_daily_metrics', 'user_daily_metrics_update_own', true, true)
)
select ok(
  (not expected.require_using or pg_get_expr(policy.polqual, policy.polrelid) like '%SELECT auth.uid()%')
    and (
      not expected.require_check
      or pg_get_expr(policy.polwithcheck, policy.polrelid) like '%SELECT auth.uid()%'
    ),
  format(
    'public.%I policy %I initializes auth.uid once per statement',
    expected.table_name,
    expected.policy_name
  )
)
from expected
join pg_class source_table on source_table.relname = expected.table_name
join pg_namespace source_schema
  on source_schema.oid = source_table.relnamespace
 and source_schema.nspname = 'public'
join pg_policy policy
  on policy.polrelid = source_table.oid
 and policy.polname = expected.policy_name;

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'habits'
      and policyname in (
        'habits - select own',
        'habits - insert own',
        'habits - update own',
        'habits - delete own'
      )
  ),
  0::bigint,
  'legacy duplicate Habit policies are absent'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'habits'
      and policyname in (
        'habits_select_own',
        'habits_insert_own',
        'habits_update_own',
        'habits_delete_own'
      )
  ),
  4::bigint,
  'one canonical owner policy remains for each Habit action'
);

select * from finish();
rollback;
