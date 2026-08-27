-- Preserve stable recurring-series identity separately from task-instance IDs.
-- Existing rows predate this column, so derive their series from the generated
-- successor delimiter before restoring the immutable-row trigger.

alter table public.task_occurrences
  add column if not exists series_id text;

drop trigger if exists task_occurrences_reject_mutation
  on public.task_occurrences;

update public.task_occurrences
set series_id = split_part(task_id, '::next::', 1)
where series_id is null or btrim(series_id) = '';

alter table public.task_occurrences
  alter column series_id set not null;

alter table public.task_occurrences
  drop constraint if exists task_occurrences_series_id_nonblank;

alter table public.task_occurrences
  add constraint task_occurrences_series_id_nonblank
  check (btrim(series_id) <> '');

create index if not exists task_occurrences_user_series_resolved_idx
  on public.task_occurrences (user_id, series_id, resolved_at desc);

create trigger task_occurrences_reject_mutation
before update on public.task_occurrences
for each row execute function public.reject_task_occurrence_mutation();
