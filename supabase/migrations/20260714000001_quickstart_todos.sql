-- INTERNAL QUICKSTART COMPATIBILITY TABLE.
--
-- This table exists only for the Supabase quickstart/example surface referenced
-- by lib/supabase_quickstart_example.dart. It is not a ChronoSpark product
-- feature, not account-owned production data, and not part of the canonical app
-- backup/sync contract. The later boundary-hardening migration revokes public
-- access before production use.

create table if not exists public.todos (
  id   bigint generated always as identity primary key,
  name text not null,
  is_complete boolean not null default false,
  inserted_at timestamptz not null default now()
);

-- Enable Row Level Security
alter table public.todos enable row level security;

-- Allow any authenticated or anonymous user to read todos
-- (quickstart demo — tighten policies for production use)
create policy "todos_select_public"
  on public.todos
  for select
  to anon, authenticated
  using (true);
