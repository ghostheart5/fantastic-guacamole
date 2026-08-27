-- Server-authoritative billing, AI reservations, durable rate limiting, and
-- Google Play lifecycle reconciliation. This migration is forward-only and
-- preserves existing purchase-token bindings.

create table if not exists public.monetization_subscription_statuses (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan_id text not null,
  product_id text not null,
  status text not null default 'free',
  is_active boolean not null default false,
  auto_renews boolean not null default false,
  period_credits integer not null default 20 check (period_credits >= 0),
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
  balance_after integer not null check (balance_after >= 0),
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
  purchase_token_hash text not null unique,
  order_id text,
  credits_granted integer not null default 0 check (credits_granted >= 0),
  subscription_plan_id text,
  payload jsonb not null default '{}'::jsonb,
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists monetization_purchases_user_idx
  on public.monetization_purchases (user_id, created_at desc);

create table if not exists public.monetization_entitlement_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_key text unique,
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

create table if not exists public.ai_usage_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_key text not null,
  state text not null check (state in ('reserved', 'completed', 'refunded', 'denied')),
  credit_amount integer not null check (credit_amount between 1 and 3),
  bonus_used integer not null default 0 check (bonus_used >= 0),
  allowance_used integer not null default 0 check (allowance_used >= 0),
  prompt_hash text not null,
  provider_request_id text,
  input_tokens integer,
  output_tokens integer,
  response_payload jsonb not null default '{}'::jsonb,
  failure_code text,
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  unique (user_id, request_key)
);

create index if not exists ai_usage_requests_user_created_idx
  on public.ai_usage_requests (user_id, created_at desc);
create index if not exists ai_usage_requests_reserved_idx
  on public.ai_usage_requests (created_at) where state = 'reserved';

create table if not exists public.backend_rate_limits (
  bucket text not null,
  subject_hash text not null,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count > 0),
  updated_at timestamptz not null default now(),
  primary key (bucket, subject_hash)
);

create index if not exists backend_rate_limits_window_idx
  on public.backend_rate_limits (window_started_at);

create table if not exists public.google_play_rtdn_events (
  message_id text primary key,
  package_name text not null,
  event_time timestamptz not null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  state text not null default 'received'
    check (state in ('received', 'processed', 'ignored', 'failed')),
  failure_code text,
  received_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.monetization_subscription_statuses enable row level security;
alter table public.monetization_wallets enable row level security;
alter table public.monetization_credit_transactions enable row level security;
alter table public.monetization_purchases enable row level security;
alter table public.monetization_entitlement_events enable row level security;
alter table public.ai_usage_requests enable row level security;
alter table public.backend_rate_limits enable row level security;
alter table public.google_play_rtdn_events enable row level security;

revoke all on table public.purchase_bindings from public, anon, authenticated, service_role;
revoke all on table public.monetization_subscription_statuses from public, anon, authenticated, service_role;
revoke all on table public.monetization_wallets from public, anon, authenticated, service_role;
revoke all on table public.monetization_credit_transactions from public, anon, authenticated, service_role;
revoke all on table public.monetization_purchases from public, anon, authenticated, service_role;
revoke all on table public.monetization_entitlement_events from public, anon, authenticated, service_role;
revoke all on table public.ai_usage_requests from public, anon, authenticated, service_role;
revoke all on table public.backend_rate_limits from public, anon, authenticated, service_role;
revoke all on table public.google_play_rtdn_events from public, anon, authenticated, service_role;

grant select on table public.monetization_subscription_statuses to authenticated;
grant select on table public.monetization_wallets to authenticated;
grant select on table public.monetization_credit_transactions to authenticated;
grant select on table public.monetization_purchases to authenticated;
grant select on table public.monetization_entitlement_events to authenticated;
grant select on table public.ai_usage_requests to authenticated;

grant select, insert on table public.purchase_bindings to service_role;
grant update (created_at) on table public.purchase_bindings to service_role;
grant select, insert, update, delete on table public.monetization_subscription_statuses to service_role;
grant select, insert, update, delete on table public.monetization_wallets to service_role;
grant select, insert on table public.monetization_credit_transactions to service_role;
grant select, insert, update, delete on table public.monetization_purchases to service_role;
grant select, insert on table public.monetization_entitlement_events to service_role;
grant select, insert, update, delete on table public.ai_usage_requests to service_role;
grant select, insert, update, delete on table public.backend_rate_limits to service_role;
grant select, insert, update on table public.google_play_rtdn_events to service_role;

drop policy if exists "monetization statuses select own" on public.monetization_subscription_statuses;
create policy "monetization statuses select own"
on public.monetization_subscription_statuses for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "monetization wallets select own" on public.monetization_wallets;
create policy "monetization wallets select own"
on public.monetization_wallets for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "monetization ledger select own" on public.monetization_credit_transactions;
create policy "monetization ledger select own"
on public.monetization_credit_transactions for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "monetization purchases select own" on public.monetization_purchases;
create policy "monetization purchases select own"
on public.monetization_purchases for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "monetization events select own" on public.monetization_entitlement_events;
create policy "monetization events select own"
on public.monetization_entitlement_events for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "ai usage select own" on public.ai_usage_requests;
create policy "ai usage select own"
on public.ai_usage_requests for select to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.ensure_monetization_wallet(p_user_id uuid)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_wallet public.monetization_wallets;
begin
  if p_user_id is null then raise exception 'user required'; end if;
  insert into public.monetization_wallets (
    user_id, balance, allowance_remaining, bonus_balance, period_credits,
    lifetime_earned, lifetime_spent, tier, period_ends_at, updated_at
  ) values (
    p_user_id, 20, 20, 0, 20, 20, 0, 'free', now() + interval '1 day', now()
  ) on conflict (user_id) do nothing returning * into v_wallet;
  if found then
    insert into public.monetization_credit_transactions (
      user_id, type, amount, balance_after, source, description
    ) values (p_user_id, 'initial_allowance', 20, 20, 'system', 'Initial daily allowance');
  else
    select * into v_wallet from public.monetization_wallets
    where user_id = p_user_id for update;
  end if;
  return v_wallet;
end;
$$;

create or replace function public.reset_monetization_allowance(p_user_id uuid)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status public.monetization_subscription_statuses;
  v_wallet public.monetization_wallets;
  v_old_balance integer;
  v_allowance integer := 20;
  v_tier text := 'free';
  v_period_end timestamptz := now() + interval '1 day';
begin
  perform public.ensure_monetization_wallet(p_user_id);
  select * into v_status from public.monetization_subscription_statuses
  where user_id = p_user_id and is_active = true
    and (expires_at is null or expires_at > now()) for update;
  if found and v_status.plan_id = 'premium_monthly' then
    v_allowance := 300;
    v_tier := 'premium_monthly';
    v_period_end := coalesce(v_status.expires_at, now() + interval '1 month');
  elsif found and v_status.plan_id = 'premium_yearly' then
    v_allowance := 360;
    v_tier := 'premium_yearly';
    v_period_end := case
      when v_status.expires_at is null then now() + interval '1 month'
      else least(v_status.expires_at, now() + interval '1 month')
    end;
  end if;
  select balance into v_old_balance from public.monetization_wallets
  where user_id = p_user_id for update;
  update public.monetization_wallets set
    balance = bonus_balance + v_allowance,
    allowance_remaining = v_allowance,
    period_credits = v_allowance,
    tier = v_tier,
    period_ends_at = v_period_end,
    updated_at = now()
  where user_id = p_user_id returning * into v_wallet;
  if v_wallet.balance <> v_old_balance then
    insert into public.monetization_credit_transactions (
      user_id, type, amount, balance_after, source, description
    ) values (
      p_user_id, 'allowance_reset', v_wallet.balance - v_old_balance,
      v_wallet.balance, 'system', 'Authoritative allowance reset'
    );
  end if;
  return v_wallet;
end;
$$;

create or replace function public.consume_backend_rate_limit(
  p_bucket text, p_subject_hash text, p_limit integer, p_window_seconds integer
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_window timestamptz;
  v_count integer;
begin
  if p_bucket !~ '^[a-z0-9_:.-]{1,80}$'
    or p_subject_hash !~ '^[0-9a-f]{64}$'
    or p_limit not between 1 and 10000
    or p_window_seconds not between 1 and 86400 then
    raise exception 'invalid rate limit request';
  end if;
  v_window := to_timestamp(
    floor(extract(epoch from clock_timestamp()) / p_window_seconds) * p_window_seconds
  );
  insert into public.backend_rate_limits (
    bucket, subject_hash, window_started_at, request_count, updated_at
  ) values (p_bucket, p_subject_hash, v_window, 1, now())
  on conflict (bucket, subject_hash) do update set
    window_started_at = case
      when public.backend_rate_limits.window_started_at = v_window
        then public.backend_rate_limits.window_started_at else v_window end,
    request_count = case
      when public.backend_rate_limits.window_started_at = v_window
        then public.backend_rate_limits.request_count + 1 else 1 end,
    updated_at = now()
  returning request_count into v_count;
  return jsonb_build_object(
    'allowed', v_count <= p_limit,
    'count', v_count,
    'resetAt', v_window + make_interval(secs => p_window_seconds)
  );
end;
$$;

create or replace function public.bind_verified_purchase_token(
  p_purchase_token_hash text, p_user_id uuid, p_product_id text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
begin
  if p_purchase_token_hash !~ '^[0-9a-f]{64}$' or p_user_id is null
    or p_product_id not in ('chronospark_premium_monthly', 'chronospark_premium_annual') then
    raise exception 'invalid purchase binding';
  end if;
  insert into public.purchase_bindings (token_hash, user_id, product_id)
  values (p_purchase_token_hash, p_user_id, p_product_id)
  on conflict (token_hash) do nothing;
  select * into v_binding from public.purchase_bindings
  where token_hash = p_purchase_token_hash for update;
  return jsonb_build_object(
    'bound', v_binding.user_id = p_user_id and v_binding.product_id = p_product_id,
    'duplicate', v_binding.user_id = p_user_id
  );
end;
$$;

create or replace function public.reserve_ai_usage(
  p_user_id uuid, p_request_key text, p_credit_amount integer, p_prompt_hash text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_existing public.ai_usage_requests;
  v_wallet public.monetization_wallets;
  v_bonus_used integer;
  v_allowance_used integer;
  v_user_daily integer;
  v_global_daily integer;
begin
  if p_user_id is null or p_request_key !~ '^[A-Za-z0-9._:=+-]{8,200}$'
    or p_credit_amount not between 1 and 3 or p_prompt_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid AI reservation request';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:ai:' || p_user_id::text || ':' || p_request_key, 0)
  );
  select * into v_existing from public.ai_usage_requests
  where user_id = p_user_id and request_key = p_request_key for update;
  if found then
    select * into v_wallet from public.monetization_wallets where user_id = p_user_id;
    if v_existing.prompt_hash <> p_prompt_hash
      or v_existing.credit_amount <> p_credit_amount then
      return jsonb_build_object(
        'allowed', false,
        'state', v_existing.state,
        'duplicate', false,
        'reason', 'idempotency_mismatch',
        'balance', coalesce(v_wallet.balance, 0)
      );
    end if;
    return jsonb_build_object(
      'allowed', v_existing.state in ('reserved', 'completed'),
      'state', v_existing.state, 'duplicate', true,
      'creditAmount', v_existing.credit_amount,
      'balance', coalesce(v_wallet.balance, 0),
      'responsePayload', v_existing.response_payload
    );
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:ai-daily-budget', 0)
  );
  select coalesce(sum(credit_amount), 0)::integer into v_user_daily
  from public.ai_usage_requests where user_id = p_user_id
    and created_at >= now() - interval '24 hours'
    and state in ('reserved', 'completed');
  select coalesce(sum(credit_amount), 0)::integer into v_global_daily
  from public.ai_usage_requests where created_at >= now() - interval '24 hours'
    and state in ('reserved', 'completed');
  if v_user_daily + p_credit_amount > 200 or v_global_daily + p_credit_amount > 20000 then
    insert into public.ai_usage_requests (
      user_id, request_key, state, credit_amount, prompt_hash, failure_code, settled_at
    ) values (
      p_user_id, p_request_key, 'denied', p_credit_amount, p_prompt_hash,
      'daily_budget_exceeded', now()
    );
    return jsonb_build_object('allowed', false, 'state', 'denied',
      'reason', 'daily_budget_exceeded');
  end if;
  perform public.ensure_monetization_wallet(p_user_id);
  select * into v_wallet from public.monetization_wallets
  where user_id = p_user_id for update;
  if v_wallet.period_ends_at is not null and v_wallet.period_ends_at <= now() then
    perform public.reset_monetization_allowance(p_user_id);
    select * into v_wallet from public.monetization_wallets
    where user_id = p_user_id for update;
  end if;
  if v_wallet.balance < p_credit_amount then
    insert into public.ai_usage_requests (
      user_id, request_key, state, credit_amount, prompt_hash, failure_code, settled_at
    ) values (
      p_user_id, p_request_key, 'denied', p_credit_amount, p_prompt_hash,
      'insufficient_credits', now()
    );
    return jsonb_build_object('allowed', false, 'state', 'denied',
      'reason', 'insufficient_credits', 'balance', v_wallet.balance);
  end if;
  v_bonus_used := least(v_wallet.bonus_balance, p_credit_amount);
  v_allowance_used := p_credit_amount - v_bonus_used;
  update public.monetization_wallets set
    bonus_balance = bonus_balance - v_bonus_used,
    allowance_remaining = greatest(allowance_remaining - v_allowance_used, 0),
    balance = balance - p_credit_amount,
    lifetime_spent = lifetime_spent + p_credit_amount,
    updated_at = now()
  where user_id = p_user_id returning * into v_wallet;
  insert into public.ai_usage_requests (
    user_id, request_key, state, credit_amount, bonus_used, allowance_used, prompt_hash
  ) values (
    p_user_id, p_request_key, 'reserved', p_credit_amount,
    v_bonus_used, v_allowance_used, p_prompt_hash
  );
  insert into public.monetization_credit_transactions (
    user_id, type, amount, balance_after, source, description, metadata
  ) values (
    p_user_id, 'spend', -p_credit_amount, v_wallet.balance, 'ai_proxy',
    'AI request reserved', jsonb_build_object('request_key', p_request_key)
  );
  return jsonb_build_object('allowed', true, 'state', 'reserved',
    'duplicate', false, 'creditAmount', p_credit_amount, 'balance', v_wallet.balance);
end;
$$;

create or replace function public.settle_ai_usage(
  p_user_id uuid, p_request_key text, p_succeeded boolean,
  p_input_tokens integer default null, p_output_tokens integer default null,
  p_provider_request_id text default null, p_failure_code text default null,
  p_response_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_usage public.ai_usage_requests;
  v_wallet public.monetization_wallets;
begin
  select * into v_usage from public.ai_usage_requests
  where user_id = p_user_id and request_key = p_request_key for update;
  if not found then raise exception 'AI reservation not found'; end if;
  if v_usage.state <> 'reserved' then
    return jsonb_build_object('state', v_usage.state, 'duplicate', true);
  end if;
  if p_succeeded then
    update public.ai_usage_requests set state = 'completed',
      input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
      output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
      provider_request_id = left(p_provider_request_id, 200),
      response_payload = coalesce(p_response_payload, '{}'::jsonb), settled_at = now()
    where id = v_usage.id;
    return jsonb_build_object('state', 'completed', 'refunded', false);
  end if;
  select * into v_wallet from public.monetization_wallets
  where user_id = p_user_id for update;
  update public.monetization_wallets set
    bonus_balance = bonus_balance + v_usage.bonus_used,
    allowance_remaining = allowance_remaining + v_usage.allowance_used,
    balance = balance + v_usage.credit_amount,
    lifetime_spent = greatest(lifetime_spent - v_usage.credit_amount, 0),
    updated_at = now()
  where user_id = p_user_id returning * into v_wallet;
  update public.ai_usage_requests set state = 'refunded',
    input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
    output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
    provider_request_id = left(p_provider_request_id, 200),
    failure_code = left(coalesce(p_failure_code, 'provider_failure'), 100),
    settled_at = now()
  where id = v_usage.id;
  insert into public.monetization_credit_transactions (
    user_id, type, amount, balance_after, source, description, metadata
  ) values (
    p_user_id, 'refund', v_usage.credit_amount, v_wallet.balance, 'ai_proxy',
    'AI request reservation refunded',
    jsonb_build_object('request_key', p_request_key, 'failure_code', p_failure_code)
  );
  return jsonb_build_object('state', 'refunded', 'refunded', true,
    'balance', v_wallet.balance);
end;
$$;

create or replace function public.refund_stale_ai_usage_reservations(
  p_older_than interval default interval '10 minutes'
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_usage public.ai_usage_requests;
  v_count integer := 0;
begin
  for v_usage in select * from public.ai_usage_requests
    where state = 'reserved' and created_at < now() - p_older_than
    order by created_at for update skip locked
  loop
    perform public.settle_ai_usage(
      v_usage.user_id, v_usage.request_key, false, null, null, null,
      'reservation_timeout', '{}'::jsonb
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.reconcile_google_play_subscription(
  p_purchase_token_hash text, p_product_id text, p_status text,
  p_is_active boolean, p_auto_renews boolean, p_order_id text,
  p_expires_at timestamptz, p_event_key text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_current public.monetization_subscription_statuses;
  v_plan_id text;
  v_period_credits integer;
  v_renewed boolean := false;
  v_wallet public.monetization_wallets;
begin
  if p_status not in ('pending', 'active', 'grace', 'on_hold', 'paused',
    'canceled', 'expired', 'revoked') then raise exception 'unsupported status'; end if;
  select * into v_binding from public.purchase_bindings
  where token_hash = p_purchase_token_hash for update;
  if not found or v_binding.product_id <> p_product_id then
    return jsonb_build_object('applied', false, 'reason', 'binding_not_found');
  end if;
  if p_event_key is not null and exists (
    select 1 from public.monetization_entitlement_events where event_key = p_event_key
  ) then return jsonb_build_object('applied', false, 'duplicate', true,
    'userId', v_binding.user_id); end if;
  v_plan_id := case p_product_id
    when 'chronospark_premium_monthly' then 'premium_monthly'
    when 'chronospark_premium_annual' then 'premium_yearly' else null end;
  v_period_credits := case v_plan_id
    when 'premium_monthly' then 300 when 'premium_yearly' then 360 else 0 end;
  if v_plan_id is null then
    return jsonb_build_object('applied', false, 'reason', 'unsupported_product');
  end if;
  select * into v_current from public.monetization_subscription_statuses
  where user_id = v_binding.user_id for update;
  v_renewed := p_is_active and p_expires_at is not null and
    (v_current.expires_at is null or p_expires_at > v_current.expires_at);
  insert into public.monetization_subscription_statuses (
    user_id, plan_id, product_id, status, is_active, auto_renews,
    period_credits, started_at, expires_at, order_id,
    purchase_token_hash, metadata, updated_at
  ) values (
    v_binding.user_id, v_plan_id, p_product_id, p_status, p_is_active,
    p_auto_renews, v_period_credits, coalesce(v_current.started_at, now()),
    p_expires_at, p_order_id, p_purchase_token_hash, p_payload, now()
  ) on conflict (user_id) do update set
    plan_id = excluded.plan_id, product_id = excluded.product_id,
    status = excluded.status, is_active = excluded.is_active,
    auto_renews = excluded.auto_renews, period_credits = excluded.period_credits,
    started_at = coalesce(public.monetization_subscription_statuses.started_at,
      excluded.started_at), expires_at = excluded.expires_at,
    order_id = excluded.order_id,
    purchase_token_hash = excluded.purchase_token_hash,
    metadata = excluded.metadata, updated_at = now();
  insert into public.monetization_purchases (
    user_id, product_id, purchase_type, purchase_state, purchase_token_hash,
    order_id, subscription_plan_id, payload, verified_at
  ) values (
    v_binding.user_id, p_product_id, 'subscription', p_status,
    p_purchase_token_hash, p_order_id, v_plan_id, p_payload, now()
  ) on conflict (purchase_token_hash) do update set
    purchase_state = excluded.purchase_state,
    order_id = coalesce(excluded.order_id, public.monetization_purchases.order_id),
    payload = excluded.payload, verified_at = now();
  v_wallet := public.reset_monetization_allowance(v_binding.user_id);
  insert into public.monetization_entitlement_events (
    user_id, event_key, event_type, plan_id, product_id, is_active,
    effective_at, expires_at, metadata
  ) values (
    v_binding.user_id, p_event_key,
    case when v_renewed then 'subscription_renewed' else 'subscription_' || p_status end,
    v_plan_id, p_product_id, p_is_active, now(), p_expires_at, p_payload
  );
  return jsonb_build_object('applied', true, 'userId', v_binding.user_id,
    'planId', v_plan_id,
    'eventType', case when v_renewed then 'subscription_renewed'
      else 'subscription_' || p_status end,
    'creditsGranted', 0, 'remainingCredits', v_wallet.balance,
    'active', p_is_active, 'renewed', v_renewed);
end;
$$;

create or replace function public.reconcile_google_play_voided_purchase(
  p_purchase_token_hash text, p_event_key text, p_order_id text default null,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_purchase public.monetization_purchases;
  v_wallet public.monetization_wallets;
begin
  select * into v_binding from public.purchase_bindings
  where token_hash = p_purchase_token_hash for update;
  if not found then return jsonb_build_object('applied', false,
    'reason', 'binding_not_found'); end if;
  if p_event_key is not null and exists (
    select 1 from public.monetization_entitlement_events where event_key = p_event_key
  ) then return jsonb_build_object('applied', false, 'duplicate', true,
    'userId', v_binding.user_id); end if;
  select * into v_purchase from public.monetization_purchases
  where purchase_token_hash = p_purchase_token_hash for update;
  if not found then return jsonb_build_object('applied', false,
    'reason', 'purchase_not_found'); end if;
  update public.monetization_purchases set purchase_state = 'refunded',
    order_id = coalesce(p_order_id, order_id), payload = payload || p_payload,
    verified_at = now() where id = v_purchase.id;
  update public.monetization_subscription_statuses set status = 'revoked',
    is_active = false, auto_renews = false, metadata = metadata || p_payload,
    updated_at = now()
  where user_id = v_binding.user_id and purchase_token_hash = p_purchase_token_hash;
  v_wallet := public.reset_monetization_allowance(v_binding.user_id);
  insert into public.monetization_entitlement_events (
    user_id, event_key, event_type, plan_id, product_id, is_active, metadata
  ) values (
    v_binding.user_id, p_event_key, 'purchase_refunded',
    v_purchase.subscription_plan_id, v_purchase.product_id, false, p_payload
  );
  return jsonb_build_object('applied', true, 'userId', v_binding.user_id,
    'productId', v_purchase.product_id, 'remainingCredits', v_wallet.balance);
end;
$$;

create or replace function public.expire_stale_monetization_subscriptions()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status public.monetization_subscription_statuses;
  v_count integer := 0;
begin
  for v_status in select * from public.monetization_subscription_statuses
    where is_active = true and expires_at is not null and expires_at <= now()
    for update skip locked
  loop
    update public.monetization_subscription_statuses set status = 'expired',
      is_active = false, auto_renews = false, updated_at = now()
    where user_id = v_status.user_id;
    perform public.reset_monetization_allowance(v_status.user_id);
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, expires_at, metadata
    ) values (
      v_status.user_id,
      'expiry:' || v_status.user_id::text || ':' ||
        extract(epoch from v_status.expires_at)::bigint::text,
      'subscription_expired', v_status.plan_id, v_status.product_id,
      false, now(), v_status.expires_at,
      jsonb_build_object('source', 'expiry_reconciliation')
    ) on conflict (event_key) do nothing;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.ensure_monetization_wallet(uuid) from public, anon, authenticated, service_role;
revoke all on function public.reset_monetization_allowance(uuid) from public, anon, authenticated, service_role;
revoke all on function public.consume_backend_rate_limit(text, text, integer, integer) from public, anon, authenticated, service_role;
revoke all on function public.bind_verified_purchase_token(text, uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.reserve_ai_usage(uuid, text, integer, text) from public, anon, authenticated, service_role;
revoke all on function public.settle_ai_usage(uuid, text, boolean, integer, integer, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.refund_stale_ai_usage_reservations(interval) from public, anon, authenticated, service_role;
revoke all on function public.reconcile_google_play_subscription(text, text, text, boolean, boolean, text, timestamptz, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.reconcile_google_play_voided_purchase(text, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.expire_stale_monetization_subscriptions() from public, anon, authenticated, service_role;

grant execute on function public.ensure_monetization_wallet(uuid) to service_role;
grant execute on function public.reset_monetization_allowance(uuid) to service_role;
grant execute on function public.consume_backend_rate_limit(text, text, integer, integer) to service_role;
grant execute on function public.bind_verified_purchase_token(text, uuid, text) to service_role;
grant execute on function public.reserve_ai_usage(uuid, text, integer, text) to service_role;
grant execute on function public.settle_ai_usage(uuid, text, boolean, integer, integer, text, text, jsonb) to service_role;
grant execute on function public.refund_stale_ai_usage_reservations(interval) to service_role;
grant execute on function public.reconcile_google_play_subscription(text, text, text, boolean, boolean, text, timestamptz, text, jsonb) to service_role;
grant execute on function public.reconcile_google_play_voided_purchase(text, text, text, jsonb) to service_role;
grant execute on function public.expire_stale_monetization_subscriptions() to service_role;

-- Billing correctness depends on both maintenance functions running even when
-- no Edge Function instance survives to perform cleanup.
create extension if not exists pg_cron;

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname in (
      'chronospark-refund-stale-ai-reservations',
      'chronospark-expire-stale-subscriptions'
    )
  loop
    perform cron.unschedule(v_job_id);
  end loop;

  perform cron.schedule(
    'chronospark-refund-stale-ai-reservations',
    '*/5 * * * *',
    'select public.refund_stale_ai_usage_reservations(interval ''10 minutes'');'
  );
  perform cron.schedule(
    'chronospark-expire-stale-subscriptions',
    '*/15 * * * *',
    'select public.expire_stale_monetization_subscriptions();'
  );
exception
  when others then
    raise exception 'failed to configure production billing cron jobs: %', sqlerrm;
end;
$$;
