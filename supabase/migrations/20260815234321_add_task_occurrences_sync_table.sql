-- Immutable, account-owned replication records for task-occurrence outcomes.
create table if not exists public.task_occurrences (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null check (btrim(id) <> ''),
  task_id text not null check (btrim(task_id) <> ''),
  occurrence_key text not null check (btrim(occurrence_key) <> ''),
  operation_id text not null check (btrim(operation_id) <> ''),
  outcome text not null check (outcome in ('completed', 'skipped', 'rescheduled')),
  original_schedule_identity timestamptz,
  resolved_at timestamptz not null,
  rescheduled_to timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  primary key (user_id, id),
  unique (user_id, task_id, occurrence_key, operation_id)
);

create index if not exists task_occurrences_user_resolved_idx
  on public.task_occurrences (user_id, resolved_at desc);

alter table public.task_occurrences enable row level security;
revoke all on table public.task_occurrences from public, anon, authenticated, service_role;
grant select, insert, update on table public.task_occurrences to authenticated;

drop policy if exists "task occurrences select own" on public.task_occurrences;
create policy "task occurrences select own"
on public.task_occurrences for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "task occurrences insert own" on public.task_occurrences;
create policy "task occurrences insert own"
on public.task_occurrences for insert to authenticated
with check ((select auth.uid()) = user_id);

-- Idempotent upserts may replay an identical row after an ambiguous response,
-- but no caller may alter an already-recorded transition.
create or replace function public.reject_task_occurrence_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new is distinct from old then
    raise exception 'task occurrences are immutable';
  end if;
  return new;
end;
$$;

revoke all on function public.reject_task_occurrence_mutation() from public, anon, authenticated, service_role;

drop trigger if exists task_occurrences_reject_mutation on public.task_occurrences;
create trigger task_occurrences_reject_mutation
before update on public.task_occurrences
for each row execute function public.reject_task_occurrence_mutation();

drop policy if exists "task occurrences replay own" on public.task_occurrences;
create policy "task occurrences replay own"
on public.task_occurrences for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
