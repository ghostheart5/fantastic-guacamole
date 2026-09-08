-- Approved 2026-09-08: $7.99 monthly / $69.99 annual, 300 credits each month;
-- free 20 monthly; optional 100/$2.99 and 300/$7.99 non-expiring top-ups.
-- Existing receipt ownership, provider reconciliation and public containment remain.
update public.monetization_subscription_plans
set price_micros = case id when 'premium_monthly' then 7990000 else 69990000 end,
    credits_per_period = 300,
    description = '300 AI credits each month; unused monthly credits expire.',
    updated_at = now()
where id in ('premium_monthly', 'premium_yearly') and currency_code = 'USD';
update public.monetization_subscription_plans set is_active = false where id = 'lifetime';
update public.monetization_credit_packages set is_active = false;
insert into public.monetization_credit_packages
  (id, product_id, name, credits, bonus_credits, price_micros, currency_code, is_active, description)
values
  ('credits_100', 'chronospark_credits_100', '100 AI credits', 100, 0, 2990000, 'USD', true, 'One-time purchase. Credits do not expire.'),
  ('credits_300', 'chronospark_credits_300', '300 AI credits', 300, 0, 7990000, 'USD', true, 'One-time purchase. Credits do not expire.')
on conflict (id) do update set credits = excluded.credits, bonus_credits = 0,
  price_micros = excluded.price_micros, is_active = true,
  description = excluded.description, updated_at = now();

alter table public.monetization_wallets
  add column allowance_anchor timestamptz,
  add column allowance_index integer not null default 0,
  add column funded_until timestamptz,
  add column credit_policy_version integer not null default 1,
  add column refunded_credit_debt integer not null default 0 check (refunded_credit_debt>=0);

-- Calendar months are calculated from the original UTC anchor, avoiding Jan-31 drift.
create function public.credit_month_boundary(p_anchor timestamptz, p_index integer)
returns timestamptz language sql immutable strict set search_path = '' as $$
  select ((p_anchor at time zone 'UTC') + make_interval(months => p_index)) at time zone 'UTC';
$$;
revoke all on function public.credit_month_boundary(timestamptz, integer) from public, anon, authenticated;
grant execute on function public.credit_month_boundary(timestamptz, integer) to service_role;

-- This transition changes cadence without giving existing accounts a second allowance.
update public.monetization_wallets
set allowance_anchor = now(), allowance_index = 0, credit_policy_version = 2,
    funded_until = case when tier in ('premium_monthly','premium_yearly') then period_ends_at end,
    period_ends_at = case when tier = 'free' then public.credit_month_boundary(now(), 1)
      else least(period_ends_at, public.credit_month_boundary(now(), 1)) end,
    period_credits = case when tier = 'free' then 20 else 300 end;

create table public.credit_topup_purchases (
  token_hash text primary key check (token_hash ~ '^[0-9a-f]{64}$'),
  billing_principal_id uuid references public.billing_principals(billing_principal_id),
  product_id text check (product_id in ('chronospark_credits_100','chronospark_credits_300')),
  order_id text unique,
  credits integer not null check (credits in (0,100,300)),
  state text not null check (state in ('granted','revoked')),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  check (state='revoked' or (credits>0 and product_id is not null and billing_principal_id is not null))
);
alter table public.credit_topup_purchases enable row level security;
revoke all on public.credit_topup_purchases from public, anon, authenticated;
grant select, insert, update on public.credit_topup_purchases to service_role;

create function public.grant_verified_credit_topup(
  p_user_id uuid, p_token_hash text, p_product_id text, p_order_id text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  v_principal uuid; v_existing public.credit_topup_purchases;
  v_wallet public.monetization_wallets; v_credits integer; v_debt_paid integer;
begin
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$'
    or nullif(btrim(p_order_id),'') is null or length(p_order_id)>1024 then
    raise exception 'invalid top-up proof';
  end if;
  select credits into v_credits from public.monetization_credit_packages
    where product_id=p_product_id and is_active;
  if v_credits not in (100,300) or v_credits is null then raise exception 'unsupported top-up'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('credit-topup:'||p_token_hash,0));
  v_principal := public.ensure_billing_principal(p_user_id);
  select * into v_existing from public.credit_topup_purchases where token_hash=p_token_hash for update;
  if found then
    if v_existing.state='revoked' then return jsonb_build_object('granted',false,'reason','revoked'); end if;
    if v_existing.billing_principal_id is distinct from v_principal or v_existing.product_id<>p_product_id then
      return jsonb_build_object('granted',false,'reason','ownership_mismatch');
    end if;
    return jsonb_build_object('granted',v_existing.state='granted','duplicate',true,'credits',v_existing.credits,'reason',v_existing.state);
  end if;
  v_wallet := public.ensure_monetization_wallet_for_principal(v_principal);
  v_debt_paid := least(v_wallet.refunded_credit_debt,v_credits);
  insert into public.credit_topup_purchases(token_hash,billing_principal_id,product_id,order_id,credits,state)
    values(p_token_hash,v_principal,p_product_id,p_order_id,v_credits,'granted');
  update public.monetization_wallets set bonus_balance=bonus_balance+v_credits-v_debt_paid,
    balance=balance+v_credits-v_debt_paid, refunded_credit_debt=refunded_credit_debt-v_debt_paid,
    lifetime_earned=lifetime_earned+v_credits,updated_at=now()
    where billing_principal_id=v_principal returning * into v_wallet;
  insert into public.monetization_credit_transactions(billing_principal_id,user_id,type,amount,balance_after,source,description,metadata)
    values(v_principal,p_user_id,'purchase',v_credits-v_debt_paid,v_wallet.balance,'google_play','Purchased non-expiring AI credits',jsonb_build_object('orderId',p_order_id,'refundedCreditsRepaid',v_debt_paid));
  return jsonb_build_object('granted',true,'duplicate',false,'credits',v_credits,'balance',v_wallet.balance);
end;
$$;
revoke all on function public.grant_verified_credit_topup(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.grant_verified_credit_topup(uuid,text,text,text) to service_role;

-- A revoke arriving before client verification creates a tombstone, blocking later grant.
create function public.revoke_verified_credit_topup(p_token_hash text, p_product_id text, p_order_id text)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_purchase public.credit_topup_purchases; v_wallet public.monetization_wallets;
  v_remove integer; v_credits integer;
begin
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then raise exception 'invalid top-up token'; end if;
  v_credits := case p_product_id when 'chronospark_credits_100' then 100 when 'chronospark_credits_300' then 300 end;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('credit-topup:'||p_token_hash,0));
  select * into v_purchase from public.credit_topup_purchases where token_hash=p_token_hash for update;
  if not found then
    insert into public.credit_topup_purchases(token_hash,product_id,order_id,credits,state,revoked_at)
      values(p_token_hash,p_product_id,p_order_id,coalesce(v_credits,0),'revoked',now());
    return jsonb_build_object('handled',true,'revoked',true);
  end if;
  if v_purchase.state='revoked' then return jsonb_build_object('handled',true,'duplicate',true); end if;
  select * into v_wallet from public.monetization_wallets where billing_principal_id=v_purchase.billing_principal_id for update;
  v_remove := least(v_wallet.bonus_balance,v_purchase.credits);
  update public.monetization_wallets set bonus_balance=bonus_balance-v_remove,balance=balance-v_remove,
    refunded_credit_debt=refunded_credit_debt+v_purchase.credits-v_remove,updated_at=now()
    where billing_principal_id=v_purchase.billing_principal_id returning * into v_wallet;
  update public.credit_topup_purchases set state='revoked',revoked_at=now() where token_hash=p_token_hash;
  insert into public.monetization_credit_transactions(billing_principal_id,user_id,type,amount,balance_after,source,description,metadata)
    values(v_purchase.billing_principal_id,v_wallet.user_id,'adjustment',-v_remove,v_wallet.balance,'google_play','Refunded top-up removed',jsonb_build_object('orderId',v_purchase.order_id,'alreadySpent',v_purchase.credits-v_remove));
  return jsonb_build_object('handled',true,'revoked',true,'removed',v_remove);
end;
$$;
revoke all on function public.revoke_verified_credit_topup(text,text,text) from public,anon,authenticated;
grant execute on function public.revoke_verified_credit_topup(text,text,text) to service_role;

create function public.credit_topup_owner(p_fingerprint text) returns jsonb
language sql security invoker set search_path = '' as $$
  select jsonb_build_object('userId',current_user_id) from public.billing_principals
  where retired_at is null and current_user_id is not null
    and encode(extensions.digest(current_user_id::text,'sha256'),'hex')=p_fingerprint;
$$;
revoke all on function public.credit_topup_owner(text) from public,anon,authenticated;
grant execute on function public.credit_topup_owner(text) to service_role;

create or replace function public.apply_monetization_allowance_grant(
  p_billing_principal_id uuid, p_purchase_token_hash text, p_order_id text,
  p_grant_cause text, p_event_key text, p_notification_type integer,
  p_credits integer, p_period_ends_at timestamptz
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb; v_plan text; v_end timestamptz;
begin
  select case product_id when 'chronospark_premium_monthly' then 'premium_monthly'
    when 'chronospark_premium_annual' then 'premium_yearly' end into v_plan
  from public.purchase_bindings where token_hash=p_purchase_token_hash
    and billing_principal_id=p_billing_principal_id;
  if v_plan is null or p_period_ends_at is null or p_period_ends_at<=now() then
    return jsonb_build_object('granted',false,'reason','invalid_paid_coverage','creditsGranted',0);
  end if;
  v_end := least(p_period_ends_at,public.credit_month_boundary(now(),1));
  v_result := public.apply_monetization_allowance_grant_phase8_base(
    p_billing_principal_id,p_purchase_token_hash,p_order_id,p_grant_cause,
    p_event_key,p_notification_type,300,v_end);
  if coalesce((v_result->>'granted')::boolean,false) then
    update public.monetization_wallets set tier=v_plan,period_credits=300,
      allowance_anchor=now(),allowance_index=0,funded_until=p_period_ends_at,
      credit_policy_version=2,period_ends_at=v_end where billing_principal_id=p_billing_principal_id;
    v_result := v_result || jsonb_build_object('creditsGranted',300);
  end if;
  return v_result;
end;
$$;

create or replace function public.reset_monetization_allowance(p_user_id uuid)
returns public.monetization_wallets language plpgsql security invoker set search_path = '' as $$
declare v_principal uuid; v_wallet public.monetization_wallets;
  v_status public.monetization_subscription_statuses; v_index integer;
  v_end timestamptz; v_amount integer; v_before integer;
begin
  v_principal := public.ensure_billing_principal(p_user_id);
  v_wallet := public.ensure_monetization_wallet_for_principal(v_principal);
  select * into v_status from public.monetization_subscription_statuses
    where billing_principal_id=v_principal for update;
  if v_wallet.period_ends_at>now() then return v_wallet; end if;
  if v_wallet.tier in ('premium_monthly','premium_yearly') then
    -- Coverage is extended only by an actual paid-order grant, never a restore.
    if v_status.is_active and v_status.status in ('active','canceled')
      and v_status.expires_at>now() and v_wallet.funded_until>now() then
      v_amount:=300;
    elsif v_status.is_active then
      -- Grace/uncertain provider state retains access but does not refill credits.
      return v_wallet;
    else
      v_wallet := public.sync_monetization_wallet_authority(v_principal,'free',
        coalesce(v_status.status,'expired'),false,null,'monthly-policy-expiry');
      return v_wallet;
    end if;
  else v_amount:=20;
  end if;
  v_index:=v_wallet.allowance_index;
  -- Skip missed windows; never accumulate a year's grants on return.
  while public.credit_month_boundary(v_wallet.allowance_anchor,v_index+1)<=now() loop
    v_index:=v_index+1;
    if v_index>2400 then raise exception 'invalid allowance anchor'; end if;
  end loop;
  v_end:=public.credit_month_boundary(v_wallet.allowance_anchor,v_index+1);
  if v_amount=300 then v_end:=least(v_end,v_wallet.funded_until,v_status.expires_at); end if;
  v_before:=v_wallet.balance;
  update public.monetization_wallets set allowance_remaining=v_amount,
    period_credits=v_amount,balance=bonus_balance+v_amount,allowance_index=v_index,
    period_ends_at=v_end,updated_at=now(),
    lifetime_earned=lifetime_earned+v_amount
    where billing_principal_id=v_principal returning * into v_wallet;
  insert into public.monetization_credit_transactions(billing_principal_id,user_id,type,amount,balance_after,source,description)
    values(v_principal,p_user_id,'allowance_reset',v_wallet.balance-v_before,v_wallet.balance,'system','Monthly AI allowance reset');
  return v_wallet;
end;
$$;

create function public.get_credit_wallet_v2() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_wallet public.monetization_wallets;
begin
  if auth.uid() is null then raise exception 'sign-in required'; end if;
  v_wallet:=public.reset_monetization_allowance(auth.uid());
  return jsonb_build_object('balance',v_wallet.balance,'tier',v_wallet.tier,
    'period_credits',v_wallet.period_credits,'period_ends_at',v_wallet.period_ends_at,
    'updated_at',v_wallet.updated_at,'allowance_remaining',v_wallet.allowance_remaining,
    'purchased_credits',v_wallet.bonus_balance,'refunded_credit_debt',v_wallet.refunded_credit_debt,'policy_version',2);
end;
$$;
revoke all on function public.get_credit_wallet_v2() from public,anon;
grant execute on function public.get_credit_wallet_v2() to authenticated;

alter table public.monetization_wallets alter column allowance_anchor set default now(), alter column credit_policy_version set default 2;
alter table public.ai_usage_requests drop constraint ai_usage_requests_credit_amount_check, add constraint ai_usage_requests_credit_amount_check check (credit_amount between 1 and 100);
create or replace function public.ensure_monetization_wallet_for_principal(
  p_billing_principal_id uuid
)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_principal public.billing_principals;
  v_wallet public.monetization_wallets;
begin
  select * into v_principal from public.billing_principals
  where billing_principal_id = p_billing_principal_id
    and retired_at is null
  for update;
  if not found then raise exception 'billing principal unavailable'; end if;

  insert into public.monetization_wallets (
    billing_principal_id, user_id, balance, allowance_remaining,
    bonus_balance, period_credits, lifetime_earned, lifetime_spent,
    tier, period_ends_at, updated_at
  ) values (
    p_billing_principal_id, v_principal.current_user_id,
    20, 20, 0, 20, 20, 0, 'free', public.credit_month_boundary(now(), 1), now()
  ) on conflict (billing_principal_id) do nothing
  returning * into v_wallet;
  if found then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description
    ) values (
      p_billing_principal_id, v_principal.current_user_id,
      'initial_allowance', 20, 20, 'system', 'Initial monthly allowance'
    );
  else
    select * into v_wallet from public.monetization_wallets
    where billing_principal_id = p_billing_principal_id for update;
  end if;
  return v_wallet;
end;
$$;
create or replace function public.sync_monetization_wallet_authority(
  p_billing_principal_id uuid,
  p_plan_id text,
  p_status text,
  p_is_active boolean,
  p_expires_at timestamptz,
  p_event_key text
)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_wallet public.monetization_wallets;
  v_user_id uuid;
  v_period_credits integer;
  v_old_balance integer;
  v_new_allowance integer;
begin
  if p_status in ('expired', 'revoked') and p_is_active then
    raise exception 'terminal subscription authority cannot be active';
  end if;
  v_wallet := public.ensure_monetization_wallet_for_principal(
    p_billing_principal_id
  );
  select current_user_id into v_user_id from public.billing_principals
  where billing_principal_id = p_billing_principal_id;
  v_period_credits := case p_plan_id
    when 'premium_monthly' then 300
    when 'premium_yearly' then 300
    else 20
  end;

  if p_is_active then
    update public.monetization_wallets
    set tier = p_plan_id,
      period_credits = v_period_credits,
      period_ends_at = least(coalesce(p_expires_at, period_ends_at), period_ends_at),
      updated_at = now()
    where billing_principal_id = p_billing_principal_id
    returning * into v_wallet;
    return v_wallet;
  end if;

  v_old_balance := v_wallet.balance;
  v_new_allowance := least(v_wallet.allowance_remaining, 20);
  update public.monetization_wallets
  set balance = bonus_balance + v_new_allowance,
    allowance_remaining = v_new_allowance,
    period_credits = 20,
    tier = 'free',
    period_ends_at = public.credit_month_boundary(now(), 1),
    allowance_anchor = now(), allowance_index = 0, funded_until = null,
    updated_at = now()
  where billing_principal_id = p_billing_principal_id
  returning * into v_wallet;
  if v_wallet.balance <> v_old_balance then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description, metadata
    ) values (
      p_billing_principal_id, v_user_id, 'authority_adjustment',
      v_wallet.balance - v_old_balance, v_wallet.balance, 'google_play',
      'Provider authority reduced the available allowance',
      jsonb_build_object('status', p_status, 'eventKey', p_event_key)
    );
  end if;
  return v_wallet;
end;
$$;
create or replace function public.reserve_ai_usage_for_principal(
  p_billing_principal_id uuid,
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
  v_principal public.billing_principals;
  v_bonus_used integer;
  v_allowance_used integer;
  v_principal_daily integer;
  v_global_daily integer;
  v_accounted bigint;
begin
  if p_billing_principal_id is null
    or p_request_key is null
    or p_request_key !~ '^[A-Za-z0-9._:=+-]{8,200}$'
    or p_credit_amount is null
    or p_credit_amount not between 1 and 100
    or p_prompt_hash is null
    or p_prompt_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid AI reservation request';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'chronospark:ai:' || p_billing_principal_id::text || ':' || p_request_key,
      0
    )
  );
  select * into v_principal from public.billing_principals
  where billing_principal_id = p_billing_principal_id
    and retired_at is null
    and current_user_id is not null
  for update;
  if not found then raise exception 'billing principal unavailable'; end if;

  select * into v_existing from public.ai_usage_requests
  where billing_principal_id = p_billing_principal_id
    and request_key = p_request_key
  for update;
  if found then
    select * into v_wallet from public.monetization_wallets
    where billing_principal_id = p_billing_principal_id;
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
      'state', v_existing.state,
      'duplicate', true,
      'creditAmount', v_existing.credit_amount,
      'balance', coalesce(v_wallet.balance, 0),
      'responsePayload', v_existing.response_payload
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:ai-daily-budget', 0)
  );
  select coalesce(sum(credit_amount), 0)::integer into v_principal_daily
  from public.ai_usage_requests
  where billing_principal_id = p_billing_principal_id
    and created_at >= now() - interval '24 hours'
    and state in ('reserved', 'completed', 'refunded');
  select coalesce(sum(credit_amount), 0)::integer into v_global_daily
  from public.ai_usage_requests
  where created_at >= now() - interval '24 hours'
    and state in ('reserved', 'completed', 'refunded');
  if v_principal_daily + p_credit_amount > 200
    or v_global_daily + p_credit_amount > 20000 then
    insert into public.ai_usage_requests (
      billing_principal_id, user_id, request_key, state, credit_amount,
      prompt_hash, failure_code, settled_at
    ) values (
      p_billing_principal_id, v_principal.current_user_id, p_request_key,
      'denied', p_credit_amount, p_prompt_hash, 'daily_budget_exceeded', now()
    );
    return jsonb_build_object(
      'allowed', false, 'state', 'denied',
      'reason', 'daily_budget_exceeded'
    );
  end if;

  v_wallet := public.ensure_monetization_wallet_for_principal(
    p_billing_principal_id
  );
  select * into v_wallet from public.monetization_wallets
  where billing_principal_id = p_billing_principal_id for update;
  if v_wallet.period_ends_at is not null
    and v_wallet.period_ends_at <= now() then
    perform public.reset_monetization_allowance(v_principal.current_user_id);
    select * into v_wallet from public.monetization_wallets
    where billing_principal_id = p_billing_principal_id for update;
  end if;

  select coalesce(sum(coalesce(accounted_provider_cost_microusd,
    reserved_provider_cost_microusd,credit_amount::bigint*3000)),0) into v_accounted
  from public.ai_usage_requests where billing_principal_id=p_billing_principal_id
    and state in ('reserved','completed','refunded');
  if v_accounted+p_credit_amount::bigint*3000 > v_wallet.lifetime_earned::bigint*3000 then
    return jsonb_build_object('allowed',false,'reason','provider_cost_budget_exceeded','balance',v_wallet.balance);
  end if;
  if v_wallet.refunded_credit_debt > 0 then
    return jsonb_build_object('allowed',false,'reason','refunded_credits_outstanding','balance',v_wallet.balance);
  end if;
  if v_wallet.balance < p_credit_amount then
    insert into public.ai_usage_requests (
      billing_principal_id, user_id, request_key, state, credit_amount,
      prompt_hash, failure_code, settled_at
    ) values (
      p_billing_principal_id, v_principal.current_user_id, p_request_key,
      'denied', p_credit_amount, p_prompt_hash, 'insufficient_credits', now()
    );
    return jsonb_build_object(
      'allowed', false, 'state', 'denied',
      'reason', 'insufficient_credits', 'balance', v_wallet.balance
    );
  end if;

  v_allowance_used := least(v_wallet.allowance_remaining, p_credit_amount);
  v_bonus_used := p_credit_amount - v_allowance_used;
  update public.monetization_wallets
  set bonus_balance = bonus_balance - v_bonus_used,
    allowance_remaining = greatest(allowance_remaining - v_allowance_used, 0),
    balance = balance - p_credit_amount,
    lifetime_spent = lifetime_spent + p_credit_amount,
    updated_at = now()
  where billing_principal_id = p_billing_principal_id
  returning * into v_wallet;
  insert into public.ai_usage_requests (
    billing_principal_id, user_id, request_key, state, credit_amount,
    bonus_used, allowance_used, prompt_hash, funding_period_ends_at, reserved_provider_cost_microusd, model_key
  ) values (
    p_billing_principal_id, v_principal.current_user_id, p_request_key,
    'reserved', p_credit_amount, v_bonus_used, v_allowance_used, p_prompt_hash, v_wallet.period_ends_at, p_credit_amount::bigint*3000, 'claude-sonnet-4-6'
  );
  insert into public.monetization_credit_transactions (
    billing_principal_id, user_id, type, amount, balance_after,
    source, description, metadata
  ) values (
    p_billing_principal_id, v_principal.current_user_id, 'spend',
    -p_credit_amount, v_wallet.balance, 'ai_proxy', 'AI request reserved',
    jsonb_build_object('request_key', p_request_key)
  );
  return jsonb_build_object(
    'allowed', true, 'state', 'reserved', 'duplicate', false,
    'creditAmount', p_credit_amount, 'balance', v_wallet.balance
  );
end;
$$;

create or replace function public.settle_ai_usage_for_principal(
  p_billing_principal_id uuid,
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
  v_principal public.billing_principals;
  v_effective_success boolean;
  v_failure_code text;
  v_allowance_refund integer;
  v_bonus_refund integer;
  v_debt_reversed integer;
  v_refund integer;
begin
  select * into v_usage from public.ai_usage_requests
  where billing_principal_id = p_billing_principal_id
    and request_key = p_request_key
  for update;
  if not found then raise exception 'AI reservation not found'; end if;
  if v_usage.state <> 'reserved' then
    return jsonb_build_object('state', v_usage.state, 'duplicate', true);
  end if;

  select * into v_principal from public.billing_principals
  where billing_principal_id = p_billing_principal_id;
  if not found then raise exception 'billing principal not found'; end if;
  v_effective_success := p_succeeded
    and v_principal.current_user_id is not null
    and v_principal.retired_at is null;
  if v_effective_success then
    update public.ai_usage_requests set state = 'completed',
      input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
      output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
      provider_request_id = left(p_provider_request_id, 200),
      response_payload = coalesce(p_response_payload, '{}'::jsonb),
      accounted_provider_cost_microusd = greatest(coalesce(p_input_tokens,0),0)::bigint*3+greatest(coalesce(p_output_tokens,0),0)::bigint*15,
      settled_at = now()
    where id = v_usage.id;
    return jsonb_build_object('state', 'completed', 'refunded', false);
  end if;

  select * into v_wallet from public.monetization_wallets
  where billing_principal_id = p_billing_principal_id for update;
  if not found then raise exception 'billing wallet not found'; end if;
  v_allowance_refund := case when v_wallet.period_ends_at is not distinct from v_usage.funding_period_ends_at
    then v_usage.allowance_used else 0 end;
  -- A Google refund can race an in-flight AI reservation. Returning the
  -- reservation cancels the matching credit debt before restoring spendable credits.
  v_debt_reversed := least(v_wallet.refunded_credit_debt,v_usage.bonus_used);
  v_bonus_refund := v_usage.bonus_used-v_debt_reversed;
  v_refund := v_bonus_refund+v_allowance_refund;
  update public.monetization_wallets set
    bonus_balance = bonus_balance + v_bonus_refund,
    refunded_credit_debt = refunded_credit_debt-v_debt_reversed,
    allowance_remaining = allowance_remaining + v_allowance_refund,
    balance = balance + v_refund,
    lifetime_spent = greatest(lifetime_spent - v_usage.credit_amount, 0),
    updated_at = now()
  where billing_principal_id = p_billing_principal_id
  returning * into v_wallet;
  v_failure_code := case
    when p_succeeded then 'account_detached'
    else coalesce(p_failure_code, 'provider_failure')
  end;
  update public.ai_usage_requests set state = 'refunded',
    input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
    output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
    provider_request_id = null,
    response_payload = '{}'::jsonb,
    failure_code = left(v_failure_code, 100),
    accounted_provider_cost_microusd = greatest(coalesce(v_usage.reserved_provider_cost_microusd,v_usage.credit_amount::bigint*3000), greatest(coalesce(p_input_tokens,0),0)::bigint*3+greatest(coalesce(p_output_tokens,0),0)::bigint*15), settled_at = now()
  where id = v_usage.id;
  if v_principal.retired_at is null then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description, metadata
    ) values (
      p_billing_principal_id, v_principal.current_user_id, 'refund',
      v_refund, v_wallet.balance, 'ai_proxy',
      'AI request reservation refunded',
      jsonb_build_object(
        'request_key', p_request_key, 'failure_code', v_failure_code
      )
    );
  end if;
  return jsonb_build_object(
    'state', 'refunded', 'refunded', true, 'balance', v_wallet.balance
  );
end;
$$;
CREATE OR REPLACE FUNCTION public.reconcile_google_play_subscription(p_purchase_token_hash text, p_product_id text, p_status text, p_is_active boolean, p_auto_renews boolean, p_order_id text, p_expires_at timestamp with time zone, p_provider_event_time timestamp with time zone, p_event_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_result jsonb;
  v_grant jsonb;
  v_billing_principal_id uuid;
  v_period_credits integer;
  v_remaining_credits integer;
  v_source text := coalesce(p_payload->>'source', 'unknown');
begin
  v_result := public.reconcile_google_play_subscription_phase8_base(
    p_purchase_token_hash, p_product_id, p_status, p_is_active,
    p_auto_renews, p_order_id, p_expires_at, p_provider_event_time,
    p_event_key, p_payload
  );

  -- A later inactive event for an already-refunded or revoked token is a
  -- successfully handled terminal transition, never a reactivation attempt.
  if v_result->>'reason' = 'terminal_token'
    and not p_is_active
    and p_status in ('expired', 'revoked') then
    return v_result || jsonb_build_object(
      'applied', true,
      'reason', 'terminal_preserved'
    );
  end if;

  -- Before Phase 8, verified non-RTDN activation sources initialized the paid
  -- allowance. Keep that compatibility path causal and idempotent while RTDN
  -- grants remain restricted to the Phase 8 notification rules.
  if coalesce((v_result->>'applied')::boolean, false)
    and p_status = 'active'
    and p_is_active
    and nullif(btrim(p_order_id), '') is not null
    and v_source <> 'google_play_rtdn' then
    select billing_principal_id into v_billing_principal_id
    from public.purchase_bindings
    where token_hash = p_purchase_token_hash;

    if v_billing_principal_id is not null
      and not exists (
        select 1 from public.monetization_allowance_grants
        where billing_principal_id = v_billing_principal_id
      ) then
      v_period_credits := case p_product_id
        when 'chronospark_premium_monthly' then 300
        when 'chronospark_premium_annual' then 300
        else 0
      end;
      v_grant := public.apply_monetization_allowance_grant(
        v_billing_principal_id, p_purchase_token_hash, p_order_id,
        'initial_activation', p_event_key, null, v_period_credits,
        p_expires_at
      );

      if coalesce((v_grant->>'granted')::boolean, false) then
        update public.monetization_entitlement_events
        set event_type = 'subscription_activated',
          metadata = metadata || jsonb_build_object(
            'allowanceGrantCause', 'initial_activation',
            'allowanceOrderId', p_order_id
          )
        where event_key = p_event_key;

        select balance into v_remaining_credits
        from public.monetization_wallets
        where billing_principal_id = v_billing_principal_id;

        v_result := v_result || jsonb_build_object(
          'eventType', 'subscription_activated',
          'creditsGranted', (v_grant->>'creditsGranted')::integer,
          'allowanceGrantReason', v_grant->>'reason',
          'remainingCredits', v_remaining_credits
        );
      end if;
    end if;
  end if;

  if coalesce((v_result->>'applied')::boolean,false) then
    update public.monetization_subscription_statuses set period_credits=case when is_active then 300 else 20 end
    where purchase_token_hash=p_purchase_token_hash;
  end if;
  return v_result;
end;
$function$
;
