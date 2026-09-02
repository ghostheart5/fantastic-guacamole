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

  return new;
end;
$$;
create or replace function public.ensure_profile_for_current_user()
returns public.profiles
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_user_id uuid := auth.uid();
  auth_user auth.users;
  profile_row public.profiles;
begin
  if current_user_id is null then
    raise exception 'auth required';
  end if;

  select * into auth_user from auth.users where id = current_user_id;
  if not found then
    raise exception 'authenticated user not found';
  end if;

  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    current_user_id,
    auth_user.email,
    coalesce(auth_user.raw_user_meta_data ->> 'full_name', auth_user.raw_user_meta_data ->> 'name'),
    auth_user.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing
  returning * into profile_row;

  if profile_row.id is null then
    select * into profile_row from public.profiles where id = current_user_id;
  end if;

  return profile_row;
end;
$$;
revoke all on function public.ensure_profile_for_current_user() from public, anon;
grant execute on function public.ensure_profile_for_current_user() to authenticated;
create or replace function public.get_global_metrics()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  avg_task_completion_rate double precision := 0;
  avg_momentum_peak double precision := 0;
begin
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
revoke all on function public.get_global_metrics() from public, anon, authenticated;
