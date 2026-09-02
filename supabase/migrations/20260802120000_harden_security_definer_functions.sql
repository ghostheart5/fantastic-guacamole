-- Harden SECURITY DEFINER function exposure.
-- SECURITY DEFINER functions in exposed schemas are executable by PUBLIC by default.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_table_schema <> 'auth' or tg_table_name <> 'users' then
    raise exception 'handle_new_user may only run from auth.users trigger context';
  end if;

  begin
    insert into public.profiles (id, email, full_name, avatar_url)
    values (
      new.id,
      new.email,
      coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
      new.raw_user_meta_data ->> 'avatar_url'
    )
    on conflict (id) do update set
      email = excluded.email,
      full_name = coalesce(excluded.full_name, public.profiles.full_name),
      avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
      updated_at = now();
  exception
    when others then
      raise warning 'handle_new_user failed for user %, error: %', new.id, sqlerrm;
  end;

  return new;
end;
$$;
revoke all on function public.handle_new_user() from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'postgres') then
    execute 'grant execute on function public.handle_new_user() to postgres';
  end if;

  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function public.handle_new_user() to service_role';
  end if;

  if exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    execute 'grant execute on function public.handle_new_user() to supabase_auth_admin';
  end if;
end;
$$;
create or replace function public.get_global_metrics()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_user_id uuid := auth.uid();
  avg_task_completion_rate double precision := 0;
  avg_momentum_peak double precision := 0;
begin
  if current_user_id is null then
    raise exception 'auth required';
  end if;

  select
    coalesce(avg(
      case
        when tasks_created > 0 then tasks_completed::double precision / tasks_created::double precision
        else 0
      end
    ), 0),
    coalesce(avg(momentum_peak), 0)
  into avg_task_completion_rate, avg_momentum_peak
  from public.user_daily_metrics;

  return jsonb_build_object(
    'avgTaskCompletionRate', avg_task_completion_rate,
    'avgMomentumPeak', avg_momentum_peak
  );
end;
$$;
revoke all on function public.get_global_metrics() from public;
grant execute on function public.get_global_metrics() to authenticated;
