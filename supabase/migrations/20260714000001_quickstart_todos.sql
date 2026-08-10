-- Quickstart todos table. This table is private to the authenticated owner.
-- It is retained for the quickstart example, but is not publicly readable.

create table if not exists public.todos (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  is_complete boolean not null default false,
  inserted_at timestamptz not null default now()
);

-- Preserve safety if a previous local environment created the quickstart table.
alter table public.todos
  add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table public.todos
  alter column user_id set default auth.uid();

create index if not exists todos_user_id_idx on public.todos (user_id);

alter table public.todos enable row level security;
revoke all on public.todos from anon;
grant select, insert, update, delete on public.todos to authenticated;

drop policy if exists "todos_select_public" on public.todos;
drop policy if exists "todos_select_own" on public.todos;
create policy "todos_select_own"
  on public.todos
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "todos_insert_own" on public.todos;
create policy "todos_insert_own"
  on public.todos
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "todos_update_own" on public.todos;
create policy "todos_update_own"
  on public.todos
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "todos_delete_own" on public.todos;
create policy "todos_delete_own"
  on public.todos
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
