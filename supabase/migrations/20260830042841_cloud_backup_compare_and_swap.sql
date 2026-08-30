create table if not exists public.cloud_backup_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null default 1,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cloud_backup_snapshots_revision_check check (revision > 0),
  constraint cloud_backup_snapshots_payload_object_check
    check (jsonb_typeof(payload) = 'object'),
  constraint cloud_backup_snapshots_payload_size_check
    check (octet_length(convert_to(payload::text, 'UTF8')) <= 5242880)
);

alter table public.cloud_backup_snapshots enable row level security;

revoke all on table public.cloud_backup_snapshots from public, anon, authenticated;
grant select, insert, update on table public.cloud_backup_snapshots
  to authenticated;

drop policy if exists cloud_backup_snapshots_select_own
  on public.cloud_backup_snapshots;
create policy cloud_backup_snapshots_select_own
on public.cloud_backup_snapshots
for select
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

drop policy if exists cloud_backup_snapshots_insert_own
  on public.cloud_backup_snapshots;
create policy cloud_backup_snapshots_insert_own
on public.cloud_backup_snapshots
for insert
to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

drop policy if exists cloud_backup_snapshots_update_own
  on public.cloud_backup_snapshots;
create policy cloud_backup_snapshots_update_own
on public.cloud_backup_snapshots
for update
to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = user_id)
with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);

create or replace function public.enforce_cloud_backup_revision()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.user_id is distinct from old.user_id then
      raise exception 'cloud backup owner is immutable';
    end if;
    if new.revision <> old.revision + 1 then
      raise exception 'cloud backup revision conflict';
    end if;
    new.created_at := old.created_at;
  elsif new.revision <> 1 then
    raise exception 'initial cloud backup revision must be one';
  end if;
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

revoke all on function public.enforce_cloud_backup_revision() from public;

drop trigger if exists enforce_cloud_backup_revision
  on public.cloud_backup_snapshots;
create trigger enforce_cloud_backup_revision
before insert or update on public.cloud_backup_snapshots
for each row execute function public.enforce_cloud_backup_revision();
