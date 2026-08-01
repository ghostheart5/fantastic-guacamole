-- CHRONOSPARK DATABASE UPGRADE SQL DRAFT (REVIEW ONLY)
-- Safe note: This is a draft artifact only. Do not execute directly in production.
-- Date: 2026-07-30

-- ============================================================
-- 1) Canonical planner facts: tasks
-- ============================================================
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'pending',
  priority int,
  difficulty int,
  energy_required int,
  scheduled_for timestamptz,
  due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_tasks_user_status
  on public.tasks(user_id, status);

create index if not exists idx_tasks_user_due_at
  on public.tasks(user_id, due_at);

-- ============================================================
-- 2) Canonical planner facts: goals
-- ============================================================
create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'active',
  target_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_goals_user_status
  on public.goals(user_id, status);

-- ============================================================
-- 3) Canonical planner facts: habits
-- ============================================================
create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  cadence text not null default 'daily',
  target_count int,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_habits_user_status
  on public.habits(user_id, status);

-- ============================================================
-- 4) Canonical planner facts: notes
-- ============================================================
create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid references public.tasks(id) on delete set null,
  body text not null,
  kind text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_notes_user_created
  on public.notes(user_id, created_at desc);

-- ============================================================
-- 5) Canonical lifecycle facts: completion_events
-- ============================================================
create table if not exists public.completion_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid references public.tasks(id) on delete set null,
  event_type text not null,
  source text,
  metadata jsonb not null default '{}'::jsonb,
  event_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_completion_events_user_event_at
  on public.completion_events(user_id, event_at desc);

create index if not exists idx_completion_events_task_event_at
  on public.completion_events(task_id, event_at desc);

-- ============================================================
-- 6) RLS draft policy pattern (apply per table after review)
-- ============================================================
-- alter table public.tasks enable row level security;
-- create policy tasks_select_own on public.tasks
--   for select using (auth.uid() = user_id);
-- create policy tasks_insert_own on public.tasks
--   for insert with check (auth.uid() = user_id);
-- create policy tasks_update_own on public.tasks
--   for update using (auth.uid() = user_id)
--   with check (auth.uid() = user_id);
-- create policy tasks_delete_own on public.tasks
--   for delete using (auth.uid() = user_id);

-- Repeat the same ownership policy family for goals, habits, notes, completion_events.

-- ============================================================
-- 7) Projection draft (timeline read model)
-- ============================================================
-- create or replace view public.timeline_projection as
-- select
--   ce.user_id,
--   ce.event_at as timeline_at,
--   ce.event_type,
--   ce.task_id,
--   t.title as task_title,
--   ce.source,
--   ce.metadata
-- from public.completion_events ce
-- left join public.tasks t on t.id = ce.task_id;

-- ============================================================
-- End of draft
-- ============================================================
