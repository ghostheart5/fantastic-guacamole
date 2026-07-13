create table if not exists public.user_daily_metrics (
  device_id text not null,
  date date not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tasks_created integer not null default 0,
  tasks_completed integer not null default 0,
  momentum_peak double precision not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (device_id, date)
);

alter table public.user_daily_metrics
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.user_daily_metrics
  alter column user_id set default auth.uid();

update public.user_daily_metrics
set user_id = auth.uid()
where user_id is null and auth.uid() is not null;

create or replace function public.set_user_daily_metrics_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  if new.user_id is null then
    new.user_id = auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists set_user_daily_metrics_updated_at on public.user_daily_metrics;
create trigger set_user_daily_metrics_updated_at
before update on public.user_daily_metrics
for each row
execute function public.set_user_daily_metrics_updated_at();

alter table public.user_daily_metrics enable row level security;

revoke all on table public.user_daily_metrics from anon;
grant select, insert, update on table public.user_daily_metrics to authenticated;

drop policy if exists "user_daily_metrics_select_authenticated" on public.user_daily_metrics;
create policy "user_daily_metrics_select_authenticated"
on public.user_daily_metrics
for select
to authenticated
using (true);

drop policy if exists "user_daily_metrics_insert_own" on public.user_daily_metrics;
create policy "user_daily_metrics_insert_own"
on public.user_daily_metrics
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "user_daily_metrics_update_own" on public.user_daily_metrics;
create policy "user_daily_metrics_update_own"
on public.user_daily_metrics
for update
to authenticated
using (user_id is null or auth.uid() = user_id)
with check (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('chronospark-sync', 'chronospark-sync', false)
on conflict (id) do update
set public = false;

drop policy if exists "chronospark_sync_select_own" on storage.objects;
create policy "chronospark_sync_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "chronospark_sync_insert_own" on storage.objects;
create policy "chronospark_sync_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "chronospark_sync_update_own" on storage.objects;
create policy "chronospark_sync_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists "chronospark_sync_delete_own" on storage.objects;
create policy "chronospark_sync_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = auth.uid()::text
);
