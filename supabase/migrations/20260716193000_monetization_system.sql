create table if not exists public.monetization_subscription_statuses (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan_id text not null,
  product_id text,
  status text not null default 'free',
  is_active boolean not null default false,
  source text not null default 'supabase',
  auto_renews boolean not null default false,
  period_credits integer not null default 20,
  started_at timestamptz,
  expires_at timestamptz,
  order_id text,
  purchase_token_hash text,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.monetization_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance integer not null default 20 check (balance >= 0),
  allowance_remaining integer not null default 20 check (allowance_remaining >= 0),
  bonus_balance integer not null default 0 check (bonus_balance >= 0),
  period_credits integer not null default 20 check (period_credits >= 0),
  lifetime_earned integer not null default 20 check (lifetime_earned >= 0),
  lifetime_spent integer not null default 0 check (lifetime_spent >= 0),
  tier text not null default 'free',
  period_ends_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.monetization_credit_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  amount integer not null,
  balance_after integer not null,
  source text not null,
  description text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists monetization_credit_transactions_user_idx
  on public.monetization_credit_transactions (user_id, created_at desc);

create table if not exists public.monetization_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null,
  purchase_type text not null,
  platform text not null default 'google_play',
  purchase_state text not null default 'verified',
  purchase_token_hash text not null,
  order_id text,
  credits_granted integer not null default 0,
  subscription_plan_id text,
  payload jsonb not null default '{}'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, purchase_token_hash)
);

create index if not exists monetization_purchases_user_idx
  on public.monetization_purchases (user_id, created_at desc);

create table if not exists public.monetization_entitlement_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  plan_id text,
  product_id text,
  is_active boolean not null default false,
  effective_at timestamptz not null default now(),
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists monetization_entitlement_events_user_idx
  on public.monetization_entitlement_events (user_id, created_at desc);

alter table public.monetization_subscription_statuses enable row level security;
alter table public.monetization_wallets enable row level security;
alter table public.monetization_credit_transactions enable row level security;
alter table public.monetization_purchases enable row level security;
alter table public.monetization_entitlement_events enable row level security;

revoke all on table public.monetization_subscription_statuses from anon, authenticated;
revoke all on table public.monetization_wallets from anon, authenticated;
revoke all on table public.monetization_credit_transactions from anon, authenticated;
revoke all on table public.monetization_purchases from anon, authenticated;
revoke all on table public.monetization_entitlement_events from anon, authenticated;

grant select on table public.monetization_subscription_statuses to authenticated;
grant select on table public.monetization_wallets to authenticated;
grant select on table public.monetization_credit_transactions to authenticated;
grant select on table public.monetization_purchases to authenticated;
grant select on table public.monetization_entitlement_events to authenticated;

drop policy if exists "monetization_subscription_statuses_select_own" on public.monetization_subscription_statuses;
create policy "monetization_subscription_statuses_select_own"
on public.monetization_subscription_statuses
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "monetization_wallets_select_own" on public.monetization_wallets;
create policy "monetization_wallets_select_own"
on public.monetization_wallets
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "monetization_credit_transactions_select_own" on public.monetization_credit_transactions;
create policy "monetization_credit_transactions_select_own"
on public.monetization_credit_transactions
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "monetization_purchases_select_own" on public.monetization_purchases;
create policy "monetization_purchases_select_own"
on public.monetization_purchases
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "monetization_entitlement_events_select_own" on public.monetization_entitlement_events;
create policy "monetization_entitlement_events_select_own"
on public.monetization_entitlement_events
for select
to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.ensure_monetization_wallet(target_user_id uuid default null)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = public
as $$
declare
  resolved_user_id uuid := coalesce(target_user_id, (select auth.uid()));
  wallet_row public.monetization_wallets;
begin
  if resolved_user_id is null then
    raise exception 'auth required';
  end if;

  insert into public.monetization_wallets (
    user_id,
    balance,
    allowance_remaining,
    bonus_balance,
    period_credits,
    lifetime_earned,
    lifetime_spent,
    tier,
    period_ends_at,
    updated_at
  )
  values (
    resolved_user_id,
    20,
    20,
    0,
    20,
    20,
    0,
    'free',
    now() + interval '1 day',
    now()
  )
  on conflict (user_id) do update
    set user_id = excluded.user_id
  returning * into wallet_row;

  return wallet_row;
end;
$$;

create or replace function public.reset_monetization_allowance(target_user_id uuid default null)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = public
as $$
declare
  resolved_user_id uuid := coalesce(target_user_id, (select auth.uid()));
  active_status public.monetization_subscription_statuses;
  wallet_row public.monetization_wallets;
begin
  if resolved_user_id is null then
    raise exception 'auth required';
  end if;

  perform public.ensure_monetization_wallet(resolved_user_id);

  select *
  into active_status
  from public.monetization_subscription_statuses
  where user_id = resolved_user_id
    and is_active = true
    and (expires_at is null or expires_at > now())
  order by updated_at desc
  limit 1;

  if found and active_status.plan_id = 'premium_monthly' then
    update public.monetization_wallets
    set tier = 'premium_monthly',
        period_credits = 250,
        allowance_remaining = 250,
        balance = bonus_balance + 250,
        period_ends_at = coalesce(active_status.expires_at, now() + interval '30 days'),
        updated_at = now()
    where user_id = resolved_user_id
    returning * into wallet_row;
  elsif found and active_status.plan_id = 'premium_yearly' then
    update public.monetization_wallets
    set tier = 'premium_yearly',
        period_credits = 4000,
        allowance_remaining = 4000,
        balance = bonus_balance + 4000,
        period_ends_at = coalesce(active_status.expires_at, now() + interval '365 days'),
        updated_at = now()
    where user_id = resolved_user_id
    returning * into wallet_row;
  elsif found and active_status.plan_id = 'lifetime' then
    update public.monetization_wallets
    set tier = 'lifetime',
        period_credits = 0,
        allowance_remaining = 0,
        balance = bonus_balance,
        period_ends_at = null,
        updated_at = now()
    where user_id = resolved_user_id
    returning * into wallet_row;
  else
    update public.monetization_wallets
    set tier = 'free',
        period_credits = 20,
        allowance_remaining = 20,
        balance = bonus_balance + 20,
        period_ends_at = now() + interval '1 day',
        updated_at = now()
    where user_id = resolved_user_id
    returning * into wallet_row;
  end if;

  return wallet_row;
end;
$$;

create or replace function public.grant_monetization_credits(
  target_user_id uuid,
  credit_amount integer,
  transaction_type text,
  transaction_source text,
  transaction_description text,
  metadata jsonb default '{}'::jsonb
)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = public
as $$
declare
  wallet_row public.monetization_wallets;
begin
  if target_user_id is null then
    raise exception 'target user required';
  end if;

  perform public.ensure_monetization_wallet(target_user_id);

  update public.monetization_wallets
  set bonus_balance = bonus_balance + credit_amount,
      balance = balance + credit_amount,
      lifetime_earned = lifetime_earned + credit_amount,
      updated_at = now()
  where user_id = target_user_id
  returning * into wallet_row;

  insert into public.monetization_credit_transactions (
    user_id,
    type,
    amount,
    balance_after,
    source,
    description,
    metadata
  )
  values (
    target_user_id,
    transaction_type,
    credit_amount,
    wallet_row.balance,
    transaction_source,
    transaction_description,
    metadata
  );

  return wallet_row;
end;
$$;

create or replace function public.consume_monetization_credits(
  credit_amount integer,
  reason text,
  metadata jsonb default '{}'::jsonb
)
returns table (
  allowed boolean,
  balance integer,
  allowance_remaining integer,
  bonus_balance integer,
  period_credits integer,
  lifetime_earned integer,
  lifetime_spent integer,
  tier text,
  updated_at timestamptz,
  period_ends_at timestamptz
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  current_user_id uuid := (select auth.uid());
  wallet_row public.monetization_wallets;
  bonus_used integer;
  allowance_used integer;
begin
  if current_user_id is null then
    raise exception 'auth required';
  end if;

  perform public.ensure_monetization_wallet(current_user_id);

  select * into wallet_row
  from public.monetization_wallets
  where user_id = current_user_id
  for update;

  if wallet_row.period_ends_at is not null and wallet_row.period_ends_at <= now() then
    perform public.reset_monetization_allowance(current_user_id);
    select * into wallet_row
    from public.monetization_wallets
    where user_id = current_user_id
    for update;
  end if;

  if wallet_row.balance < credit_amount then
    return query
    select false,
           wallet_row.balance,
           wallet_row.allowance_remaining,
           wallet_row.bonus_balance,
           wallet_row.period_credits,
           wallet_row.lifetime_earned,
           wallet_row.lifetime_spent,
           wallet_row.tier,
           wallet_row.updated_at,
           wallet_row.period_ends_at;
    return;
  end if;

  bonus_used := least(wallet_row.bonus_balance, credit_amount);
  allowance_used := credit_amount - bonus_used;

  update public.monetization_wallets
  set bonus_balance = bonus_balance - bonus_used,
      allowance_remaining = greatest(allowance_remaining - allowance_used, 0),
      balance = balance - credit_amount,
      lifetime_spent = lifetime_spent + credit_amount,
      updated_at = now()
  where user_id = current_user_id
  returning * into wallet_row;

  insert into public.monetization_credit_transactions (
    user_id,
    type,
    amount,
    balance_after,
    source,
    description,
    metadata
  )
  values (
    current_user_id,
    'spend',
    -credit_amount,
    wallet_row.balance,
    'app',
    reason,
    metadata
  );

  return query
  select true,
         wallet_row.balance,
         wallet_row.allowance_remaining,
         wallet_row.bonus_balance,
         wallet_row.period_credits,
         wallet_row.lifetime_earned,
         wallet_row.lifetime_spent,
         wallet_row.tier,
         wallet_row.updated_at,
         wallet_row.period_ends_at;
end;
$$;

create or replace function public.apply_verified_purchase(
  target_user_id uuid,
  product_id text,
  purchase_type text,
  purchase_token_hash text,
  order_id text default null,
  verified_at timestamptz default now(),
  expires_at timestamptz default null,
  payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  existing_purchase public.monetization_purchases;
  current_status public.monetization_subscription_statuses;
  wallet_row public.monetization_wallets;
  resolved_plan_id text := null;
  credits_to_grant integer := 0;
  event_type text := null;
begin
  if target_user_id is null then
    raise exception 'target user required';
  end if;

  perform public.ensure_monetization_wallet(target_user_id);

  select * into existing_purchase
  from public.monetization_purchases
  where user_id = target_user_id
    and purchase_token_hash = apply_verified_purchase.purchase_token_hash
  limit 1;

  if found then
    return jsonb_build_object(
      'applied', false,
      'duplicate', true,
      'productId', existing_purchase.product_id,
      'creditsGranted', existing_purchase.credits_granted,
      'planId', existing_purchase.subscription_plan_id
    );
  end if;

  select * into current_status
  from public.monetization_subscription_statuses
  where user_id = target_user_id
  limit 1;

  if product_id = 'chronospark_premium_monthly' then
    resolved_plan_id := 'premium_monthly';
    event_type := case
      when current_status.user_id is not null and current_status.expires_at is not null and expires_at is not null and expires_at > current_status.expires_at then 'subscription_renewed'
      else 'subscription_started'
    end;

    insert into public.monetization_subscription_statuses (
      user_id, plan_id, product_id, status, is_active, source, auto_renews,
      period_credits, started_at, expires_at, order_id, purchase_token_hash,
      metadata, updated_at
    )
    values (
      target_user_id, resolved_plan_id, product_id, 'active', true, 'google_play', true,
      250, coalesce(current_status.started_at, verified_at), expires_at, order_id,
      purchase_token_hash, payload, now()
    )
    on conflict (user_id) do update
      set plan_id = excluded.plan_id,
          product_id = excluded.product_id,
          status = excluded.status,
          is_active = excluded.is_active,
          source = excluded.source,
          auto_renews = excluded.auto_renews,
          period_credits = excluded.period_credits,
          started_at = coalesce(public.monetization_subscription_statuses.started_at, excluded.started_at),
          expires_at = excluded.expires_at,
          order_id = excluded.order_id,
          purchase_token_hash = excluded.purchase_token_hash,
          metadata = excluded.metadata,
          updated_at = now();

    perform public.reset_monetization_allowance(target_user_id);
    select * into wallet_row from public.monetization_wallets where user_id = target_user_id;

    insert into public.monetization_credit_transactions (
      user_id, type, amount, balance_after, source, description, metadata
    )
    values (
      target_user_id,
      'subscription_grant',
      250,
      wallet_row.balance,
      'google_play',
      'Premium monthly credits applied',
      jsonb_build_object('product_id', product_id, 'event_type', event_type)
    );
  elsif product_id = 'chronospark_premium_annual' then
    resolved_plan_id := 'premium_yearly';
    event_type := case
      when current_status.user_id is not null and current_status.expires_at is not null and expires_at is not null and expires_at > current_status.expires_at then 'subscription_renewed'
      else 'subscription_started'
    end;

    insert into public.monetization_subscription_statuses (
      user_id, plan_id, product_id, status, is_active, source, auto_renews,
      period_credits, started_at, expires_at, order_id, purchase_token_hash,
      metadata, updated_at
    )
    values (
      target_user_id, resolved_plan_id, product_id, 'active', true, 'google_play', true,
      4000, coalesce(current_status.started_at, verified_at), expires_at, order_id,
      purchase_token_hash, payload, now()
    )
    on conflict (user_id) do update
      set plan_id = excluded.plan_id,
          product_id = excluded.product_id,
          status = excluded.status,
          is_active = excluded.is_active,
          source = excluded.source,
          auto_renews = excluded.auto_renews,
          period_credits = excluded.period_credits,
          started_at = coalesce(public.monetization_subscription_statuses.started_at, excluded.started_at),
          expires_at = excluded.expires_at,
          order_id = excluded.order_id,
          purchase_token_hash = excluded.purchase_token_hash,
          metadata = excluded.metadata,
          updated_at = now();

    perform public.reset_monetization_allowance(target_user_id);
    select * into wallet_row from public.monetization_wallets where user_id = target_user_id;

    insert into public.monetization_credit_transactions (
      user_id, type, amount, balance_after, source, description, metadata
    )
    values (
      target_user_id,
      'subscription_grant',
      4000,
      wallet_row.balance,
      'google_play',
      'Premium yearly credits applied',
      jsonb_build_object('product_id', product_id, 'event_type', event_type)
    );
  elsif product_id = 'chronospark_lifetime' then
    resolved_plan_id := 'lifetime';
    event_type := 'subscription_started';

    insert into public.monetization_subscription_statuses (
      user_id, plan_id, product_id, status, is_active, source, auto_renews,
      period_credits, started_at, expires_at, order_id, purchase_token_hash,
      metadata, updated_at
    )
    values (
      target_user_id, resolved_plan_id, product_id, 'active', true, 'google_play', false,
      0, coalesce(current_status.started_at, verified_at), null, order_id,
      purchase_token_hash, payload, now()
    )
    on conflict (user_id) do update
      set plan_id = excluded.plan_id,
          product_id = excluded.product_id,
          status = excluded.status,
          is_active = excluded.is_active,
          source = excluded.source,
          auto_renews = excluded.auto_renews,
          period_credits = excluded.period_credits,
          started_at = coalesce(public.monetization_subscription_statuses.started_at, excluded.started_at),
          expires_at = excluded.expires_at,
          order_id = excluded.order_id,
          purchase_token_hash = excluded.purchase_token_hash,
          metadata = excluded.metadata,
          updated_at = now();

    credits_to_grant := 1000;
    wallet_row := public.grant_monetization_credits(
      target_user_id,
      credits_to_grant,
      'purchase_grant',
      'google_play',
      'Lifetime starter credits applied',
      jsonb_build_object('product_id', product_id)
    );

    update public.monetization_wallets
    set tier = 'lifetime',
        period_credits = 0,
        allowance_remaining = 0,
        balance = bonus_balance,
        period_ends_at = null,
        updated_at = now()
    where user_id = target_user_id
    returning * into wallet_row;
  elsif product_id = 'chronospark_credits_100' then
    credits_to_grant := 100;
    event_type := 'credit_pack_purchased';
    wallet_row := public.grant_monetization_credits(
      target_user_id,
      credits_to_grant,
      'purchase_grant',
      'google_play',
      '100-credit pack applied',
      jsonb_build_object('product_id', product_id)
    );
  elsif product_id = 'chronospark_credits_500' then
    credits_to_grant := 575;
    event_type := 'credit_pack_purchased';
    wallet_row := public.grant_monetization_credits(
      target_user_id,
      credits_to_grant,
      'purchase_grant',
      'google_play',
      '500-credit pack with bonus applied',
      jsonb_build_object('product_id', product_id, 'bonus', 75)
    );
  elsif product_id = 'chronospark_credits_1200' then
    credits_to_grant := 1400;
    event_type := 'credit_pack_purchased';
    wallet_row := public.grant_monetization_credits(
      target_user_id,
      credits_to_grant,
      'purchase_grant',
      'google_play',
      '1200-credit pack with bonus applied',
      jsonb_build_object('product_id', product_id, 'bonus', 200)
    );
  elsif product_id = 'chronospark_credits_3000' then
    credits_to_grant := 3600;
    event_type := 'credit_pack_purchased';
    wallet_row := public.grant_monetization_credits(
      target_user_id,
      credits_to_grant,
      'purchase_grant',
      'google_play',
      '3000-credit pack with bonus applied',
      jsonb_build_object('product_id', product_id, 'bonus', 600)
    );
  else
    raise exception 'unsupported product id: %', product_id;
  end if;

  insert into public.monetization_purchases (
    user_id,
    product_id,
    purchase_type,
    platform,
    purchase_state,
    purchase_token_hash,
    order_id,
    credits_granted,
    subscription_plan_id,
    payload,
    verified_at
  )
  values (
    target_user_id,
    product_id,
    purchase_type,
    'google_play',
    'verified',
    purchase_token_hash,
    order_id,
    credits_to_grant,
    resolved_plan_id,
    payload,
    verified_at
  );

  insert into public.monetization_entitlement_events (
    user_id,
    event_type,
    plan_id,
    product_id,
    is_active,
    effective_at,
    expires_at,
    metadata
  )
  values (
    target_user_id,
    coalesce(event_type, 'subscription_started'),
    resolved_plan_id,
    product_id,
    resolved_plan_id is not null,
    verified_at,
    expires_at,
    payload
  );

  if wallet_row.user_id is null then
    select * into wallet_row from public.monetization_wallets where user_id = target_user_id;
  end if;

  return jsonb_build_object(
    'applied', true,
    'productId', product_id,
    'planId', resolved_plan_id,
    'creditsGranted', credits_to_grant,
    'eventType', event_type,
    'balance', wallet_row.balance
  );
end;
$$;

revoke all on function public.ensure_monetization_wallet(uuid) from public;
revoke all on function public.reset_monetization_allowance(uuid) from public;
revoke all on function public.grant_monetization_credits(uuid, integer, text, text, text, jsonb) from public;
revoke all on function public.consume_monetization_credits(integer, text, jsonb) from public;
revoke all on function public.apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb) from public;

grant execute on function public.ensure_monetization_wallet(uuid) to authenticated, service_role;
grant execute on function public.reset_monetization_allowance(uuid) to authenticated, service_role;
grant execute on function public.consume_monetization_credits(integer, text, jsonb) to authenticated;
grant execute on function public.grant_monetization_credits(uuid, integer, text, text, text, jsonb) to service_role;
grant execute on function public.apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb) to service_role;