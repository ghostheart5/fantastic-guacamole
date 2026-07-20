delete from public.user_daily_metrics
where user_id is null;

create temp table _chronospark_user_daily_metrics_rollup as
select
  min(device_id) as device_id,
  date,
  user_id,
  sum(tasks_created) as tasks_created,
  sum(tasks_completed) as tasks_completed,
  max(momentum_peak) as momentum_peak,
  min(created_at) as created_at,
  max(updated_at) as updated_at
from public.user_daily_metrics
group by user_id, date;

truncate table public.user_daily_metrics;

insert into public.user_daily_metrics (
  device_id,
  date,
  user_id,
  tasks_created,
  tasks_completed,
  momentum_peak,
  created_at,
  updated_at
)
select
  device_id,
  date,
  user_id,
  tasks_created,
  tasks_completed,
  momentum_peak,
  created_at,
  updated_at
from _chronospark_user_daily_metrics_rollup;

drop table _chronospark_user_daily_metrics_rollup;

alter table public.user_daily_metrics
  alter column user_id set not null;

alter table public.user_daily_metrics
  drop constraint if exists user_daily_metrics_pkey;

alter table public.user_daily_metrics
  add constraint user_daily_metrics_pkey primary key (user_id, date);

create index if not exists user_daily_metrics_device_date_idx
  on public.user_daily_metrics (device_id, date);

drop policy if exists "user_daily_metrics_select_authenticated" on public.user_daily_metrics;
create policy "user_daily_metrics_select_own"
on public.user_daily_metrics
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "user_daily_metrics_update_own" on public.user_daily_metrics;
create policy "user_daily_metrics_update_own"
on public.user_daily_metrics
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop function if exists public.get_global_metrics();
create or replace function public.get_global_metrics()
returns jsonb
language plpgsql
security definer
set search_path = public
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