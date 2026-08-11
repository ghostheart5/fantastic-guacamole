-- Production backend controls for AI usage, Google Play lifecycle events,
-- catalog availability, and durable account deletion.

create table if not exists public.monetization_subscription_plans (
  id text primary key,
  name text not null,
  product_id text not null unique,
  plan_type text not null check (plan_type in ('subscription', 'inapp')),
  price_micros bigint not null default 0 check (price_micros >= 0),
  currency_code text not null default 'USD',
  billing_period text not null,
  credits_per_period integer not null default 0 check (credits_per_period >= 0),
  is_active boolean not null default true,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.monetization_credit_packages (
  id text primary key,
  product_id text not null unique,
  name text not null,
  credits integer not null check (credits > 0),
  bonus_credits integer not null default 0 check (bonus_credits >= 0),
  price_micros bigint not null default 0 check (price_micros >= 0),
  currency_code text not null default 'USD',
  is_active boolean not null default true,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.monetization_subscription_plans enable row level security;
alter table public.monetization_credit_packages enable row level security;
revoke all on table public.monetization_subscription_plans from public, anon, authenticated, service_role;
revoke all on table public.monetization_credit_packages from public, anon, authenticated, service_role;
grant select on table public.monetization_subscription_plans to authenticated;
grant select on table public.monetization_credit_packages to authenticated;
grant select, insert, update, delete on table public.monetization_subscription_plans to service_role;
grant select, insert, update, delete on table public.monetization_credit_packages to service_role;

drop policy if exists "active subscription plans are readable" on public.monetization_subscription_plans;
create policy "active subscription plans are readable"
on public.monetization_subscription_plans for select to authenticated
using (is_active = true);

drop policy if exists "active credit packages are readable" on public.monetization_credit_packages;
create policy "active credit packages are readable"
on public.monetization_credit_packages for select to authenticated
using (is_active = true);

-- Prices shown during checkout must come from Google Play ProductDetails. These
-- rows define product identity and entitlements; price_micros is intentionally
-- zero until an authorized catalog synchronization writes Play metadata.
insert into public.monetization_subscription_plans (
  id, name, product_id, plan_type, price_micros, currency_code,
  billing_period, credits_per_period, is_active, description
)
values
  ('premium_monthly', 'Premium Monthly', 'chronospark_premium_monthly', 'subscription', 0, 'USD', 'monthly', 250, true, 'Monthly premium access and AI allowance.'),
  ('premium_yearly', 'Premium Annual', 'chronospark_premium_annual', 'subscription', 0, 'USD', 'annual', 4000, true, 'Annual premium access and AI allowance.'),
  ('lifetime', 'Lifetime', 'chronospark_lifetime', 'inapp', 0, 'USD', 'lifetime', 0, true, 'Lifetime premium access.')
on conflict (id) do update set
  name = excluded.name,
  product_id = excluded.product_id,
  plan_type = excluded.plan_type,
  billing_period = excluded.billing_period,
  credits_per_period = excluded.credits_per_period,
  is_active = excluded.is_active,
  description = excluded.description,
  updated_at = now();

insert into public.monetization_credit_packages (
  id, product_id, name, credits, bonus_credits, price_micros,
  currency_code, is_active, description
)
values
  ('credits_100', 'chronospark_credits_100', '100 Credits', 100, 0, 0, 'USD', true, '100 AI credits.'),
  ('credits_500', 'chronospark_credits_500', '500 Credits', 500, 75, 0, 'USD', true, '500 AI credits plus 75 bonus credits.'),
  ('credits_1200', 'chronospark_credits_1200', '1200 Credits', 1200, 200, 0, 'USD', true, '1200 AI credits plus 200 bonus credits.'),
  ('credits_3000', 'chronospark_credits_3000', '3000 Credits', 3000, 600, 0, 'USD', true, '3000 AI credits plus 600 bonus credits.')
on conflict (id) do update set
  product_id = excluded.product_id,
  name = excluded.name,
  credits = excluded.credits,
  bonus_credits = excluded.bonus_credits,
  is_active = excluded.is_active,
  description = excluded.description,
  updated_at = now();

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
  on public.ai_usage_requests (created_at)
  where state = 'reserved';

alter table public.ai_usage_requests enable row level security;
revoke all on table public.ai_usage_requests from public, anon, authenticated, service_role;
grant select on table public.ai_usage_requests to authenticated;
grant select, insert, update on table public.ai_usage_requests to service_role;

drop policy if exists "ai usage requests select own" on public.ai_usage_requests;
create policy "ai usage requests select own"
on public.ai_usage_requests for select to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.reserve_ai_usage(
  p_user_id uuid,
  p_request_key text,
  p_credit_amount integer,
  p_prompt_hash text
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
  if p_user_id is null
    or p_request_key !~ '^[A-Za-z0-9._:-]{8,128}$'
    or p_credit_amount not between 1 and 3
    or p_prompt_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid AI reservation request';
  end if;

  select * into v_existing
  from public.ai_usage_requests
  where user_id = p_user_id and request_key = p_request_key
  for update;

  if found then
    return jsonb_build_object(
      'allowed', v_existing.state in ('reserved', 'completed'),
      'state', v_existing.state,
      'duplicate', true,
      'creditAmount', v_existing.credit_amount,
      'responsePayload', v_existing.response_payload
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:ai-daily-budget', 0)
  );

  select coalesce(sum(credit_amount), 0)::integer into v_user_daily
  from public.ai_usage_requests
  where user_id = p_user_id
    and created_at >= now() - interval '24 hours'
    and state in ('reserved', 'completed');

  select coalesce(sum(credit_amount), 0)::integer into v_global_daily
  from public.ai_usage_requests
  where created_at >= now() - interval '24 hours'
    and state in ('reserved', 'completed');

  if v_user_daily + p_credit_amount > 200 or v_global_daily + p_credit_amount > 20000 then
    insert into public.ai_usage_requests (
      user_id, request_key, state, credit_amount, prompt_hash, failure_code, settled_at
    ) values (
      p_user_id, p_request_key, 'denied', p_credit_amount, p_prompt_hash,
      'daily_budget_exceeded', now()
    );
    return jsonb_build_object(
      'allowed', false,
      'state', 'denied',
      'reason', 'daily_budget_exceeded'
    );
  end if;

  perform public.ensure_monetization_wallet(p_user_id);
  select * into v_wallet
  from public.monetization_wallets
  where user_id = p_user_id
  for update;

  if v_wallet.period_ends_at is not null and v_wallet.period_ends_at <= now() then
    perform public.reset_monetization_allowance(p_user_id);
    select * into v_wallet
    from public.monetization_wallets
    where user_id = p_user_id
    for update;
  end if;

  if v_wallet.balance < p_credit_amount then
    insert into public.ai_usage_requests (
      user_id, request_key, state, credit_amount, prompt_hash, failure_code, settled_at
    ) values (
      p_user_id, p_request_key, 'denied', p_credit_amount, p_prompt_hash,
      'insufficient_credits', now()
    );
    return jsonb_build_object(
      'allowed', false,
      'state', 'denied',
      'reason', 'insufficient_credits',
      'balance', v_wallet.balance
    );
  end if;

  v_bonus_used := least(v_wallet.bonus_balance, p_credit_amount);
  v_allowance_used := p_credit_amount - v_bonus_used;

  update public.monetization_wallets
  set bonus_balance = bonus_balance - v_bonus_used,
      allowance_remaining = greatest(allowance_remaining - v_allowance_used, 0),
      balance = balance - p_credit_amount,
      lifetime_spent = lifetime_spent + p_credit_amount,
      updated_at = now()
  where user_id = p_user_id
  returning * into v_wallet;

  insert into public.ai_usage_requests (
    user_id, request_key, state, credit_amount, bonus_used,
    allowance_used, prompt_hash
  ) values (
    p_user_id, p_request_key, 'reserved', p_credit_amount, v_bonus_used,
    v_allowance_used, p_prompt_hash
  );

  insert into public.monetization_credit_transactions (
    user_id, type, amount, balance_after, source, description, metadata
  ) values (
    p_user_id, 'spend', -p_credit_amount, v_wallet.balance, 'ai_proxy',
    'AI request reserved', jsonb_build_object('request_key', p_request_key)
  );

  return jsonb_build_object(
    'allowed', true,
    'state', 'reserved',
    'duplicate', false,
    'creditAmount', p_credit_amount,
    'balance', v_wallet.balance
  );
end;
$$;

create or replace function public.settle_ai_usage(
  p_user_id uuid,
  p_request_key text,
  p_succeeded boolean,
  p_input_tokens integer default null,
  p_output_tokens integer default null,
  p_provider_request_id text default null,
  p_failure_code text default null,
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
  select * into v_usage
  from public.ai_usage_requests
  where user_id = p_user_id and request_key = p_request_key
  for update;

  if not found then
    raise exception 'AI reservation not found';
  end if;
  if v_usage.state <> 'reserved' then
    return jsonb_build_object('state', v_usage.state, 'duplicate', true);
  end if;

  if p_succeeded then
    update public.ai_usage_requests
    set state = 'completed',
        input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
        output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
        provider_request_id = left(p_provider_request_id, 200),
        response_payload = coalesce(p_response_payload, '{}'::jsonb),
        settled_at = now()
    where id = v_usage.id;
    return jsonb_build_object('state', 'completed', 'refunded', false);
  end if;

  select * into v_wallet
  from public.monetization_wallets
  where user_id = p_user_id
  for update;

  update public.monetization_wallets
  set bonus_balance = bonus_balance + v_usage.bonus_used,
      allowance_remaining = allowance_remaining + v_usage.allowance_used,
      balance = balance + v_usage.credit_amount,
      lifetime_spent = greatest(lifetime_spent - v_usage.credit_amount, 0),
      updated_at = now()
  where user_id = p_user_id
  returning * into v_wallet;

  update public.ai_usage_requests
  set state = 'refunded',
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

  return jsonb_build_object(
    'state', 'refunded', 'refunded', true, 'balance', v_wallet.balance
  );
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
  for v_usage in
    select * from public.ai_usage_requests
    where state = 'reserved' and created_at < now() - p_older_than
    order by created_at
    for update skip locked
  loop
    perform public.settle_ai_usage(
      v_usage.user_id,
      v_usage.request_key,
      false,
      null,
      null,
      null,
      'reservation_timeout',
      '{}'::jsonb
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.reserve_ai_usage(uuid, text, integer, text) from public, anon, authenticated, service_role;
revoke all on function public.settle_ai_usage(uuid, text, boolean, integer, integer, text, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.refund_stale_ai_usage_reservations(interval) from public, anon, authenticated, service_role;
grant execute on function public.reserve_ai_usage(uuid, text, integer, text) to service_role;
grant execute on function public.settle_ai_usage(uuid, text, boolean, integer, integer, text, text, jsonb) to service_role;
grant execute on function public.refund_stale_ai_usage_reservations(interval) to service_role;

alter table public.monetization_entitlement_events
  add column if not exists event_key text;
create unique index if not exists monetization_entitlement_events_event_key_idx
  on public.monetization_entitlement_events (event_key)
  where event_key is not null;

create table if not exists public.google_play_rtdn_events (
  message_id text primary key,
  package_name text not null,
  event_time timestamptz not null,
  event_type text not null,
  purchase_token_hash text,
  payload jsonb not null default '{}'::jsonb,
  state text not null default 'received' check (state in ('received', 'processed', 'ignored', 'failed')),
  failure_code text,
  received_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.google_play_rtdn_events enable row level security;
revoke all on table public.google_play_rtdn_events from public, anon, authenticated, service_role;
grant select, insert, update on table public.google_play_rtdn_events to service_role;

create or replace function public.reconcile_google_play_subscription(
  p_purchase_token_hash text,
  p_product_id text,
  p_status text,
  p_is_active boolean,
  p_auto_renews boolean,
  p_order_id text,
  p_expires_at timestamptz,
  p_event_key text,
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
  v_purchase public.monetization_purchases;
  v_plan_id text;
  v_period_credits integer;
  v_renewed boolean := false;
begin
  if p_status not in ('pending', 'active', 'grace', 'on_hold', 'paused', 'canceled', 'expired', 'revoked') then
    raise exception 'unsupported subscription status';
  end if;

  select * into v_binding
  from public.purchase_bindings
  where token_hash = p_purchase_token_hash
  for update;
  if not found or v_binding.product_id <> p_product_id then
    return jsonb_build_object('applied', false, 'reason', 'binding_not_found');
  end if;

  v_plan_id := case p_product_id
    when 'chronospark_premium_monthly' then 'premium_monthly'
    when 'chronospark_premium_annual' then 'premium_yearly'
    else null
  end;
  v_period_credits := case v_plan_id
    when 'premium_monthly' then 250
    when 'premium_yearly' then 4000
    else 0
  end;
  if v_plan_id is null then
    return jsonb_build_object('applied', false, 'reason', 'unsupported_product');
  end if;

  select * into v_current
  from public.monetization_subscription_statuses
  where user_id = v_binding.user_id
  for update;

  if p_event_key is not null and exists (
    select 1 from public.monetization_entitlement_events where event_key = p_event_key
  ) then
    return jsonb_build_object('applied', false, 'duplicate', true, 'userId', v_binding.user_id);
  end if;

  v_renewed := p_is_active
    and p_expires_at is not null
    and (v_current.expires_at is null or p_expires_at > v_current.expires_at);

  insert into public.monetization_subscription_statuses (
    user_id, plan_id, product_id, status, is_active, source, auto_renews,
    period_credits, started_at, expires_at, order_id, purchase_token_hash,
    metadata, updated_at
  ) values (
    v_binding.user_id, v_plan_id, p_product_id, p_status, p_is_active,
    'google_play', p_auto_renews, v_period_credits,
    coalesce(v_current.started_at, now()), p_expires_at, p_order_id,
    p_purchase_token_hash, p_payload, now()
  ) on conflict (user_id) do update set
    plan_id = excluded.plan_id,
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

  select * into v_purchase
  from public.monetization_purchases
  where user_id = v_binding.user_id and purchase_token_hash = p_purchase_token_hash
  for update;

  if found then
    update public.monetization_purchases
    set purchase_state = p_status,
        order_id = coalesce(p_order_id, order_id),
        payload = p_payload,
        verified_at = now()
    where id = v_purchase.id;
  else
    insert into public.monetization_purchases (
      user_id, product_id, purchase_type, platform, purchase_state,
      purchase_token_hash, order_id, credits_granted, subscription_plan_id,
      payload, verified_at
    ) values (
      v_binding.user_id, p_product_id, 'subscription', 'google_play', p_status,
      p_purchase_token_hash, p_order_id, 0, v_plan_id, p_payload, now()
    );
  end if;

  if v_renewed then
    perform public.reset_monetization_allowance(v_binding.user_id);
  elsif not p_is_active and v_current.purchase_token_hash = p_purchase_token_hash then
    perform public.reset_monetization_allowance(v_binding.user_id);
  end if;

  insert into public.monetization_entitlement_events (
    user_id, event_type, plan_id, product_id, is_active, effective_at,
    expires_at, metadata, event_key
  ) values (
    v_binding.user_id,
    case when v_renewed then 'subscription_renewed' else 'subscription_' || p_status end,
    v_plan_id, p_product_id, p_is_active, now(), p_expires_at, p_payload, p_event_key
  );

  return jsonb_build_object(
    'applied', true,
    'userId', v_binding.user_id,
    'planId', v_plan_id,
    'eventType', case when v_renewed then 'subscription_renewed' else 'subscription_' || p_status end,
    'creditsGranted', 0,
    'status', p_status,
    'active', p_is_active,
    'renewed', v_renewed
  );
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
  for v_status in
    select * from public.monetization_subscription_statuses
    where is_active = true
      and plan_id <> 'lifetime'
      and expires_at is not null
      and expires_at <= now()
    for update skip locked
  loop
    update public.monetization_subscription_statuses
    set status = 'expired', is_active = false, auto_renews = false, updated_at = now()
    where user_id = v_status.user_id;
    perform public.reset_monetization_allowance(v_status.user_id);
    insert into public.monetization_entitlement_events (
      user_id, event_type, plan_id, product_id, is_active, effective_at,
      expires_at, metadata, event_key
    ) values (
      v_status.user_id, 'subscription_expired', v_status.plan_id,
      v_status.product_id, false, now(), v_status.expires_at,
      jsonb_build_object('source', 'expiry_reconciliation'),
      'expiry:' || v_status.user_id::text || ':' || extract(epoch from v_status.expires_at)::bigint::text
    ) on conflict (event_key) where event_key is not null do nothing;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.reconcile_google_play_voided_purchase(
  p_purchase_token_hash text,
  p_event_key text,
  p_order_id text default null,
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
  v_status public.monetization_subscription_statuses;
  v_wallet public.monetization_wallets;
  v_recovered integer := 0;
  v_unrecovered integer := 0;
begin
  select * into v_binding
  from public.purchase_bindings
  where token_hash = p_purchase_token_hash
  for update;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'binding_not_found');
  end if;

  if p_event_key is not null and exists (
    select 1 from public.monetization_entitlement_events where event_key = p_event_key
  ) then
    return jsonb_build_object('applied', false, 'duplicate', true, 'userId', v_binding.user_id);
  end if;

  select * into v_purchase
  from public.monetization_purchases
  where user_id = v_binding.user_id and purchase_token_hash = p_purchase_token_hash
  for update;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'purchase_not_found');
  end if;

  update public.monetization_purchases
  set purchase_state = 'refunded',
      order_id = coalesce(p_order_id, order_id),
      payload = payload || p_payload,
      verified_at = now()
  where id = v_purchase.id;

  if v_purchase.subscription_plan_id is not null then
    select * into v_status
    from public.monetization_subscription_statuses
    where user_id = v_binding.user_id
    for update;
    if found and v_status.purchase_token_hash = p_purchase_token_hash then
      update public.monetization_subscription_statuses
      set status = 'revoked', is_active = false, auto_renews = false,
          metadata = metadata || p_payload, updated_at = now()
      where user_id = v_binding.user_id;
      perform public.reset_monetization_allowance(v_binding.user_id);
    end if;
  elsif v_purchase.credits_granted > 0 then
    select * into v_wallet
    from public.monetization_wallets
    where user_id = v_binding.user_id
    for update;
    v_recovered := least(v_purchase.credits_granted, v_wallet.bonus_balance);
    v_unrecovered := v_purchase.credits_granted - v_recovered;
    update public.monetization_wallets
    set bonus_balance = bonus_balance - v_recovered,
        balance = greatest(balance - v_recovered, 0),
        lifetime_earned = greatest(lifetime_earned - v_recovered, 0),
        updated_at = now()
    where user_id = v_binding.user_id
    returning * into v_wallet;
    insert into public.monetization_credit_transactions (
      user_id, type, amount, balance_after, source, description, metadata
    ) values (
      v_binding.user_id, 'refund_reversal', -v_recovered, v_wallet.balance,
      'google_play', 'Voided Google Play credit purchase',
      jsonb_build_object(
        'event_key', p_event_key,
        'credits_granted', v_purchase.credits_granted,
        'unrecovered_credits', v_unrecovered
      )
    );
  end if;

  insert into public.monetization_entitlement_events (
    user_id, event_type, plan_id, product_id, is_active, effective_at,
    expires_at, metadata, event_key
  ) values (
    v_binding.user_id, 'purchase_refunded', v_purchase.subscription_plan_id,
    v_purchase.product_id, false, now(), null,
    p_payload || jsonb_build_object('unrecovered_credits', v_unrecovered),
    p_event_key
  );

  return jsonb_build_object(
    'applied', true,
    'userId', v_binding.user_id,
    'productId', v_purchase.product_id,
    'creditsRecovered', v_recovered,
    'unrecoveredCredits', v_unrecovered
  );
end;
$$;

revoke all on function public.reconcile_google_play_subscription(text, text, text, boolean, boolean, text, timestamptz, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.expire_stale_monetization_subscriptions() from public, anon, authenticated, service_role;
revoke all on function public.reconcile_google_play_voided_purchase(text, text, text, jsonb) from public, anon, authenticated, service_role;
grant execute on function public.reconcile_google_play_subscription(text, text, text, boolean, boolean, text, timestamptz, text, jsonb) to service_role;
grant execute on function public.expire_stale_monetization_subscriptions() to service_role;
grant execute on function public.reconcile_google_play_voided_purchase(text, text, text, jsonb) to service_role;

create table if not exists public.account_deletion_requests (
  request_id text primary key,
  user_id uuid not null unique,
  receipt_hash text not null unique,
  state text not null default 'requested'
    check (state in ('requested', 'sessions_revoked', 'storage_deleted', 'completed', 'failed')),
  lease_id uuid,
  lease_until timestamptz,
  attempts integer not null default 0,
  sessions_revoked_at timestamptz,
  storage_deleted_at timestamptz,
  auth_deleted_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists account_deletion_requests_pending_idx
  on public.account_deletion_requests (updated_at)
  where state <> 'completed';

alter table public.account_deletion_requests enable row level security;
revoke all on table public.account_deletion_requests from public, anon, authenticated, service_role;
grant select, insert, update on table public.account_deletion_requests to service_role;

create or replace function public.claim_account_deletion_request(
  p_request_id text,
  p_receipt_hash text,
  p_user_id uuid default null,
  p_lease_id uuid default gen_random_uuid(),
  p_allow_internal boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests;
begin
  if p_request_id !~ '^[0-9a-f]{64}$'
    or (not p_allow_internal and p_receipt_hash !~ '^[0-9a-f]{64}$') then
    raise exception 'invalid deletion request';
  end if;

  if p_user_id is not null then
    select * into v_request
    from public.account_deletion_requests
    where user_id = p_user_id
    for update;

    if found and v_request.request_id <> p_request_id then
      if v_request.sessions_revoked_at is not null then
        return jsonb_build_object(
          'claimed', false,
          'reason', 'existing_request_after_revocation'
        );
      end if;
      update public.account_deletion_requests
      set request_id = p_request_id,
          receipt_hash = p_receipt_hash,
          lease_id = null,
          lease_until = null,
          attempts = 0,
          last_error_code = null,
          updated_at = now()
      where user_id = p_user_id;
    elsif not found then
      insert into public.account_deletion_requests (
        request_id, user_id, receipt_hash, state, updated_at
      ) values (
        p_request_id, p_user_id, p_receipt_hash, 'requested', now()
      ) on conflict (request_id) do nothing;
    end if;
  end if;

  select * into v_request
  from public.account_deletion_requests
  where request_id = p_request_id
    and (
      receipt_hash = p_receipt_hash
      or p_allow_internal
    )
  for update;

  if not found or (p_user_id is not null and v_request.user_id <> p_user_id) then
    return jsonb_build_object('claimed', false, 'reason', 'not_found');
  end if;
  if v_request.state = 'completed' then
    return jsonb_build_object(
      'claimed', false, 'completed', true, 'state', v_request.state,
      'userId', v_request.user_id
    );
  end if;
  if v_request.lease_until is not null and v_request.lease_until > now() then
    return jsonb_build_object('claimed', false, 'state', v_request.state, 'retry', true);
  end if;

  update public.account_deletion_requests
  set lease_id = p_lease_id,
      lease_until = now() + interval '45 seconds',
      attempts = attempts + 1,
      updated_at = now()
  where request_id = p_request_id;

  return jsonb_build_object(
    'claimed', true,
    'leaseId', p_lease_id,
    'state', v_request.state,
    'userId', v_request.user_id,
    'sessionsRevoked', v_request.sessions_revoked_at is not null,
    'storageDeleted', v_request.storage_deleted_at is not null
  );
end;
$$;

revoke all on function public.claim_account_deletion_request(text, text, uuid, uuid, boolean) from public, anon, authenticated, service_role;
grant execute on function public.claim_account_deletion_request(text, text, uuid, uuid, boolean) to service_role;

-- This narrowly scoped SECURITY DEFINER function is required because Auth
-- sessions live outside the exposed public schema. It can operate only on the
-- user attached to a currently leased, durable deletion request.
create or replace function public.revoke_account_deletion_sessions(
  p_request_id text,
  p_lease_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  select user_id into v_user_id
  from public.account_deletion_requests
  where request_id = p_request_id
    and lease_id = p_lease_id
    and lease_until > now()
    and state <> 'completed'
  for update;

  if v_user_id is null then
    return false;
  end if;

  delete from auth.sessions where user_id = v_user_id;
  return true;
end;
$$;

revoke all on function public.revoke_account_deletion_sessions(text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.revoke_account_deletion_sessions(text, uuid) to service_role;

create or replace function public.account_deletion_in_progress()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.account_deletion_requests
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.account_deletion_in_progress() from public, anon, authenticated, service_role;
grant execute on function public.account_deletion_in_progress() to authenticated;

create extension if not exists pg_cron;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname in (
    'chronospark-expire-subscriptions',
    'chronospark-refund-stale-ai-reservations'
  );

  perform cron.schedule(
    'chronospark-expire-subscriptions',
    '*/15 * * * *',
    'select public.expire_stale_monetization_subscriptions();'
  );
  perform cron.schedule(
    'chronospark-refund-stale-ai-reservations',
    '*/5 * * * *',
    'select public.refund_stale_ai_usage_reservations(interval ''10 minutes'');'
  );
end;
$$;

-- Reject new Storage writes once a durable deletion request exists. Existing
-- object policies remain ownership-scoped; these replacements add the tombstone.
drop policy if exists "chronospark_sync_insert_own" on storage.objects;
create policy "chronospark_sync_insert_own"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chronospark-sync'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not public.account_deletion_in_progress()
);

drop policy if exists "chronospark_sync_update_own" on storage.objects;
create policy "chronospark_sync_update_own"
on storage.objects for update to authenticated
using (
  bucket_id = 'chronospark-sync'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not public.account_deletion_in_progress()
)
with check (
  bucket_id = 'chronospark-sync'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not public.account_deletion_in_progress()
);
