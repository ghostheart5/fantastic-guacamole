-- Keep device push tokens out of mutable auth user_metadata.
create table if not exists public.user_push_tokens (
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  source text not null default 'app',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

alter table public.user_push_tokens enable row level security;
revoke all on table public.user_push_tokens from anon, authenticated;
grant select, insert, update, delete on table public.user_push_tokens to authenticated;

create index if not exists user_push_tokens_user_id_idx
  on public.user_push_tokens (user_id);

drop policy if exists "user_push_tokens_select_own" on public.user_push_tokens;
create policy "user_push_tokens_select_own"
on public.user_push_tokens for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "user_push_tokens_insert_own" on public.user_push_tokens;
create policy "user_push_tokens_insert_own"
on public.user_push_tokens for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "user_push_tokens_update_own" on public.user_push_tokens;
create policy "user_push_tokens_update_own"
on public.user_push_tokens for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "user_push_tokens_delete_own" on public.user_push_tokens;
create policy "user_push_tokens_delete_own"
on public.user_push_tokens for delete to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.set_user_push_tokens_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_user_push_tokens_updated_at on public.user_push_tokens;
create trigger set_user_push_tokens_updated_at
before update on public.user_push_tokens
for each row execute function public.set_user_push_tokens_updated_at();

revoke execute on function public.set_user_push_tokens_updated_at()
  from public, anon, authenticated;
