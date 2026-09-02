create table if not exists public.tasks (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null check (btrim(id) <> ''),
  title text not null check (btrim(title) <> ''),
  description text,
  kind text,
  priority integer not null default 3 check (priority between 0 and 5),
  difficulty integer not null default 3 check (difficulty between 0 and 5),
  energy_required integer not null default 3 check (energy_required between 0 and 5),
  scheduled_for timestamptz,
  goal_id text,
  subtasks jsonb not null default '[]'::jsonb check (jsonb_typeof(subtasks) = 'array'),
  recurrence_rule text not null default 'none' check (recurrence_rule in ('none', 'daily', 'weekly', 'monthly')),
  is_completed boolean not null default false,
  completed_at timestamptz,
  is_canceled boolean not null default false,
  due_date timestamptz,
  estimated_duration_ms integer check (estimated_duration_ms is null or estimated_duration_ms >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);
create table if not exists public.goals (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null check (btrim(id) <> ''),
  title text not null check (btrim(title) <> ''),
  description text,
  target_date timestamptz,
  color_hex bigint not null default 4288387835 check (color_hex between 0 and 4294967295),
  status text not null default 'active' check (status in ('active', 'completed', 'archived')),
  completed_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);
create table if not exists public.habits (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null check (btrim(id) <> ''),
  title text not null check (btrim(title) <> ''),
  description text,
  cadence text not null default 'daily' check (cadence in ('daily', 'weekly', 'monthly')),
  target_count integer not null default 1 check (target_count between 1 and 365),
  status text not null default 'active' check (status in ('active', 'paused', 'archived')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);
create table if not exists public.settings (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null check (id = 'default'),
  sound_enabled boolean not null default true,
  notifications_enabled boolean not null default true,
  theme_mode text not null default 'system' check (theme_mode in ('system', 'light', 'dark')),
  onboarding_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);
create index if not exists tasks_user_updated_idx on public.tasks (user_id, updated_at);
create index if not exists goals_user_updated_idx on public.goals (user_id, updated_at);
create index if not exists habits_user_updated_idx on public.habits (user_id, updated_at);
create index if not exists settings_user_updated_idx on public.settings (user_id, updated_at);
alter table public.tasks enable row level security;
alter table public.goals enable row level security;
alter table public.habits enable row level security;
alter table public.settings enable row level security;
revoke all on public.tasks, public.goals, public.habits, public.settings from anon;
grant select, insert, update, delete on public.tasks, public.goals, public.habits, public.settings to authenticated;
drop policy if exists "tasks_select_own" on public.tasks;
create policy "tasks_select_own" on public.tasks for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "tasks_insert_own" on public.tasks;
create policy "tasks_insert_own" on public.tasks for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "tasks_update_own" on public.tasks;
create policy "tasks_update_own" on public.tasks for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "tasks_delete_own" on public.tasks;
create policy "tasks_delete_own" on public.tasks for delete to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "goals_select_own" on public.goals;
create policy "goals_select_own" on public.goals for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "goals_insert_own" on public.goals;
create policy "goals_insert_own" on public.goals for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "goals_update_own" on public.goals;
create policy "goals_update_own" on public.goals for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "goals_delete_own" on public.goals;
create policy "goals_delete_own" on public.goals for delete to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "habits_select_own" on public.habits;
create policy "habits_select_own" on public.habits for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "habits_insert_own" on public.habits;
create policy "habits_insert_own" on public.habits for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "habits_update_own" on public.habits;
create policy "habits_update_own" on public.habits for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "habits_delete_own" on public.habits;
create policy "habits_delete_own" on public.habits for delete to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "settings_select_own" on public.settings;
create policy "settings_select_own" on public.settings for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "settings_insert_own" on public.settings;
create policy "settings_insert_own" on public.settings for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "settings_update_own" on public.settings;
create policy "settings_update_own" on public.settings for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "settings_delete_own" on public.settings;
create policy "settings_delete_own" on public.settings for delete to authenticated using ((select auth.uid()) = user_id);
