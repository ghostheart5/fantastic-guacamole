create table if not exists public.purchase_bindings (
  token_hash text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null,
  created_at timestamptz not null default now()
);

alter table public.purchase_bindings enable row level security;

revoke all on table public.purchase_bindings from anon, authenticated;

grant select, insert, update, delete on table public.purchase_bindings to authenticated;

drop policy if exists "purchase_bindings_select_own" on public.purchase_bindings;
create policy "purchase_bindings_select_own"
on public.purchase_bindings
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "purchase_bindings_insert_own" on public.purchase_bindings;
create policy "purchase_bindings_insert_own"
on public.purchase_bindings
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "purchase_bindings_update_own" on public.purchase_bindings;
create policy "purchase_bindings_update_own"
on public.purchase_bindings
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "purchase_bindings_delete_own" on public.purchase_bindings;
create policy "purchase_bindings_delete_own"
on public.purchase_bindings
for delete
to authenticated
using (auth.uid() = user_id);
