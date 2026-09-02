-- Deleting an Auth user must not leave account-linked rows behind. The hosted
-- schema audit on 2026-08-09 found eleven user-owned tables without an
-- auth.users foreign key and app_events using ON DELETE SET NULL. All audited
-- tables were empty at capture time, but this migration still validates every
-- constraint and aborts on orphaned rows if state changes before deployment.
--
-- Some hosted tables are not yet represented by local creation migrations.
-- Missing relations are intentionally skipped here so the migration remains
-- replayable while schema drift is recovered; the paired pgTAP contract fails
-- for every missing relation, preventing a production approval from silently
-- accepting that incomplete local schema.

do $account_deletion_cascades$
declare
  target record;
  relation_oid regclass;
  user_id_attnum smallint;
  existing_constraint_name text;
  existing_delete_action "char";
  has_orphans boolean;
begin
  for target in
    select *
    from (values
      ('app_events', 'app_events_user_id_fkey'),
      ('core_values', 'core_values_user_id_fkey'),
      ('goals', 'goals_user_id_fkey'),
      ('habit entries', 'habit_entries_user_id_fkey'),
      ('milestones', 'milestones_user_id_fkey'),
      ('notifications', 'notifications_user_id_fkey'),
      ('settings', 'settings_user_id_fkey'),
      ('smart coach notes', 'smart_coach_notes_user_id_fkey'),
      ('soul_maps', 'soul_maps_user_id_fkey'),
      ('tasks', 'tasks_user_id_fkey'),
      ('timeline_events', 'timeline_events_user_id_fkey'),
      ('webhook_events', 'webhook_events_user_id_fkey')
    ) as expected(table_name, constraint_name)
  loop
    relation_oid := to_regclass(format('public.%I', target.table_name));
    if relation_oid is null then
      raise notice 'Skipping missing drifted relation public.%', target.table_name;
      continue;
    end if;

    select a.attnum::smallint
      into user_id_attnum
    from pg_attribute a
    where a.attrelid = relation_oid
      and a.attname = 'user_id'
      and a.attnum > 0
      and not a.attisdropped;

    if user_id_attnum is null then
      raise exception 'public.% has no user_id column', target.table_name;
    end if;

    existing_constraint_name := null;
    existing_delete_action := null;
    select c.conname, c.confdeltype
      into existing_constraint_name, existing_delete_action
    from pg_constraint c
    where c.contype = 'f'
      and c.conrelid = relation_oid
      and c.confrelid = 'auth.users'::regclass
      and c.conkey = array[user_id_attnum]::smallint[]
    order by c.oid
    limit 1;

    if existing_delete_action = 'c' then
      continue;
    end if;

    execute format(
      'select exists (' ||
      'select 1 from %s owned ' ||
      'left join auth.users account on account.id = owned.user_id ' ||
      'where owned.user_id is not null and account.id is null' ||
      ')',
      relation_oid
    ) into has_orphans;

    if has_orphans then
      raise exception
        'Cannot add account-deletion cascade: public.% contains orphaned user_id values',
        target.table_name;
    end if;

    if existing_constraint_name is not null then
      execute format(
        'alter table %s drop constraint %I',
        relation_oid,
        existing_constraint_name
      );
    end if;

    execute format(
      'alter table %s add constraint %I ' ||
      'foreign key (user_id) references auth.users(id) ' ||
      'on delete cascade not valid',
      relation_oid,
      target.constraint_name
    );
    execute format(
      'alter table %s validate constraint %I',
      relation_oid,
      target.constraint_name
    );
  end loop;
end;
$account_deletion_cascades$;
