create table if not exists public.tasks (
  created_at timestamptz not null default now(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'text'::text,
  completed boolean not null default false,
  id uuid not null default gen_random_uuid(),
  description text default 'text'::text,
  due_date timestamptz,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (id)
);

create table if not exists public.goals (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  description text,
  target_date timestamptz,
  status text,
  importance integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (id)
);

create table if not exists public.habits (
  created_at timestamptz not null default now(),
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text default 'text'::text,
  color text default 'text'::text,
  icon text default 'text'::text,
  target_frequency smallint not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (id)
);

create table if not exists public.settings (
  id uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null default gen_random_uuid() references auth.users(id) on delete cascade,
  theme text not null default 'prismcore'::text,
  notifications_enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (id)
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
