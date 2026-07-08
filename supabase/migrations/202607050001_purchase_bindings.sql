create table if not exists public.purchase_bindings (
  token_hash text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null,
  created_at timestamptz not null default now()
);

alter table public.purchase_bindings enable row level security;

revoke all on table public.purchase_bindings from anon, authenticated;
