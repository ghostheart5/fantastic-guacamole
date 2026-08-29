-- Keep Google Play lifecycle transitions monotonic without treating every
-- active state change as a paid allowance renewal.

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
  v_silent_grace boolean := false;
begin
  perform public.ensure_monetization_wallet(p_user_id);
  select * into v_status
  from public.monetization_subscription_statuses
  where user_id = p_user_id
    and is_active = true
    and (
      expires_at is null
      or expires_at > now()
      or (
        status = 'active'
        and auto_renews = true
        and expires_at > now() - interval '24 hours'
      )
    )
  for update;

  v_silent_grace := found
    and v_status.status = 'active'
    and v_status.auto_renews = true
    and v_status.expires_at is not null
    and v_status.expires_at <= now();

  if found and v_status.plan_id = 'premium_monthly' then
    v_allowance := 300;
    v_tier := 'premium_monthly';
    v_period_end := case
      when v_silent_grace then v_status.expires_at + interval '24 hours'
      else coalesce(v_status.expires_at, now() + interval '1 month')
    end;
  elsif found and v_status.plan_id = 'premium_yearly' then
    v_allowance := 360;
    v_tier := 'premium_yearly';
    v_period_end := case
      when v_silent_grace then v_status.expires_at + interval '24 hours'
      when v_status.expires_at is null then now() + interval '1 month'
      else least(v_status.expires_at, now() + interval '1 month')
    end;
  end if;

  if v_silent_grace then
    update public.monetization_wallets
    set period_credits = v_allowance,
      tier = v_tier,
      period_ends_at = v_period_end,
      updated_at = now()
    where user_id = p_user_id
    returning * into v_wallet;
    return v_wallet;
  end if;

  select balance into v_old_balance
  from public.monetization_wallets
  where user_id = p_user_id
  for update;
  update public.monetization_wallets
  set balance = bonus_balance + v_allowance,
    allowance_remaining = v_allowance,
    period_credits = v_allowance,
    tier = v_tier,
    period_ends_at = v_period_end,
    updated_at = now()
  where user_id = p_user_id
  returning * into v_wallet;
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

create or replace function public.reconcile_google_play_subscription(
  p_purchase_token_hash text,
  p_product_id text,
  p_status text,
  p_is_active boolean,
  p_auto_renews boolean,
  p_order_id text,
  p_expires_at timestamptz,
  p_provider_event_time timestamptz,
  p_event_key text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_current_binding public.purchase_bindings;
  v_current public.monetization_subscription_statuses;
  v_purchase public.monetization_purchases;
  v_plan_id text;
  v_period_credits integer;
  v_renewed boolean := false;
  v_wallet public.monetization_wallets;
  v_payload jsonb;
  v_event_count integer;
  v_incoming_is_predecessor boolean := false;
  v_current_is_predecessor boolean := false;
  v_should_reset_allowance boolean := false;
begin
  if p_status not in ('pending', 'active', 'grace', 'on_hold', 'paused',
    'canceled', 'expired', 'revoked') then
    raise exception 'unsupported status';
  end if;
  if p_provider_event_time is null then
    raise exception 'provider event time is required';
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
    when 'premium_monthly' then 300
    when 'premium_yearly' then 360
    else 0
  end;
  if v_plan_id is null then
    return jsonb_build_object('applied', false, 'reason', 'unsupported_product');
  end if;

  v_payload := coalesce(p_payload, '{}'::jsonb) || jsonb_build_object(
    'providerEventTime', p_provider_event_time
  );

  select * into v_current
  from public.monetization_subscription_statuses
  where user_id = v_binding.user_id
  for update;

  if v_current.user_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash then
    select * into v_current_binding
    from public.purchase_bindings
    where token_hash = v_current.purchase_token_hash;

    with recursive current_ancestry(token_hash, path) as (
      select v_current.purchase_token_hash,
        array[v_current.purchase_token_hash]
      union all
      select binding.predecessor_token_hash,
        current_ancestry.path || binding.predecessor_token_hash
      from current_ancestry
      join public.purchase_bindings binding
        on binding.token_hash = current_ancestry.token_hash
      where binding.predecessor_token_hash is not null
        and not binding.predecessor_token_hash = any(current_ancestry.path)
    )
    select exists (
      select 1 from current_ancestry
      where token_hash = p_purchase_token_hash
    ) into v_incoming_is_predecessor;

    with recursive incoming_ancestry(token_hash, path) as (
      select p_purchase_token_hash, array[p_purchase_token_hash]
      union all
      select binding.predecessor_token_hash,
        incoming_ancestry.path || binding.predecessor_token_hash
      from incoming_ancestry
      join public.purchase_bindings binding
        on binding.token_hash = incoming_ancestry.token_hash
      where binding.predecessor_token_hash is not null
        and not binding.predecessor_token_hash = any(incoming_ancestry.path)
    )
    select exists (
      select 1 from incoming_ancestry
      where token_hash = v_current.purchase_token_hash
    ) into v_current_is_predecessor;
  end if;

  select * into v_purchase
  from public.monetization_purchases
  where purchase_token_hash = p_purchase_token_hash
  for update;

  if p_event_key is not null and exists (
    select 1
    from public.monetization_entitlement_events
    where event_key = p_event_key
  ) then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_binding.user_id
    );
  end if;

  if v_current.user_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash
    and (
      not p_is_active
      or v_current_binding.token_hash is null
      or v_incoming_is_predecessor
      or (
        not v_current_is_predecessor
        and v_binding.created_at <= v_current_binding.created_at
      )
    ) then
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, expires_at, metadata
    ) values (
      v_binding.user_id, p_event_key,
      'subscription_' || p_status || '_old_token',
      v_plan_id, p_product_id, p_is_active, p_provider_event_time,
      p_expires_at, v_payload
    ) on conflict (event_key) do nothing;

    insert into public.monetization_purchases (
      user_id, product_id, purchase_type, purchase_state,
      purchase_token_hash, order_id, subscription_plan_id, payload, verified_at
    ) values (
      v_binding.user_id, p_product_id, 'subscription', p_status,
      p_purchase_token_hash, p_order_id, v_plan_id, v_payload, now()
    ) on conflict (purchase_token_hash) do update set
      purchase_state = case
        when public.monetization_purchases.purchase_state = 'refunded'
          then public.monetization_purchases.purchase_state
        else excluded.purchase_state
      end,
      order_id = coalesce(excluded.order_id, public.monetization_purchases.order_id),
      payload = public.monetization_purchases.payload || excluded.payload,
      verified_at = now();

    return jsonb_build_object(
      'applied', false, 'handled', true, 'reason', 'old_token',
      'userId', v_binding.user_id, 'active', v_current.is_active
    );
  end if;

  if v_current.user_id is not null
    and v_current.purchase_token_hash is not distinct from p_purchase_token_hash
    and p_is_active
    and (
      v_current.status = 'revoked'
      or v_purchase.purchase_state = 'refunded'
    ) then
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, expires_at, metadata
    ) values (
      v_binding.user_id, p_event_key, 'subscription_terminal_token_ignored',
      v_plan_id, p_product_id, false, p_provider_event_time,
      p_expires_at, v_payload
    ) on conflict (event_key) do nothing;
    return jsonb_build_object(
      'applied', false, 'handled', true, 'reason', 'terminal_token',
      'userId', v_binding.user_id, 'active', false
    );
  end if;

  if v_current.user_id is not null
    and (
      v_current.provider_event_time > p_provider_event_time
      or (
        v_current.provider_event_time = p_provider_event_time
        and not v_current.is_active
        and p_is_active
        and not (
          p_expires_at is not null
          and v_current.expires_at is not null
          and p_expires_at > v_current.expires_at
        )
      )
    ) then
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, expires_at, metadata
    ) values (
      v_binding.user_id, p_event_key, 'subscription_stale_ignored',
      v_plan_id, p_product_id, p_is_active, p_provider_event_time,
      p_expires_at, v_payload
    ) on conflict (event_key) do nothing;
    return jsonb_build_object(
      'applied', false, 'handled', true, 'stale', true,
      'reason', 'stale_event', 'userId', v_binding.user_id
    );
  end if;

  v_renewed := p_status = 'active' and p_is_active
    and p_expires_at is not null
    and (v_current.expires_at is null or p_expires_at > v_current.expires_at);
  v_should_reset_allowance := v_current.user_id is null
    or v_current.is_active is distinct from p_is_active
    or v_current.plan_id is distinct from v_plan_id
    or v_renewed;

  insert into public.monetization_entitlement_events (
    user_id, event_key, event_type, plan_id, product_id, is_active,
    effective_at, expires_at, metadata
  ) values (
    v_binding.user_id, p_event_key,
    case when v_renewed then 'subscription_renewed'
      else 'subscription_' || p_status end,
    v_plan_id, p_product_id, p_is_active, p_provider_event_time,
    p_expires_at, v_payload
  ) on conflict (event_key) do nothing;
  get diagnostics v_event_count = row_count;
  if p_event_key is not null and v_event_count = 0 then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_binding.user_id
    );
  end if;

  insert into public.monetization_subscription_statuses (
    user_id, plan_id, product_id, status, is_active, auto_renews,
    period_credits, started_at, expires_at, order_id,
    purchase_token_hash, provider_event_time, metadata, updated_at
  ) values (
    v_binding.user_id, v_plan_id, p_product_id, p_status, p_is_active,
    p_auto_renews, v_period_credits, coalesce(v_current.started_at, now()),
    p_expires_at, p_order_id, p_purchase_token_hash, p_provider_event_time,
    v_payload, now()
  ) on conflict (user_id) do update set
    plan_id = excluded.plan_id,
    product_id = excluded.product_id,
    status = excluded.status,
    is_active = excluded.is_active,
    auto_renews = excluded.auto_renews,
    period_credits = excluded.period_credits,
    started_at = coalesce(
      public.monetization_subscription_statuses.started_at,
      excluded.started_at
    ),
    expires_at = excluded.expires_at,
    order_id = excluded.order_id,
    purchase_token_hash = excluded.purchase_token_hash,
    provider_event_time = greatest(
      public.monetization_subscription_statuses.provider_event_time,
      excluded.provider_event_time
    ),
    metadata = excluded.metadata,
    updated_at = now();

  insert into public.monetization_purchases (
    user_id, product_id, purchase_type, purchase_state, purchase_token_hash,
    order_id, subscription_plan_id, payload, verified_at
  ) values (
    v_binding.user_id, p_product_id, 'subscription', p_status,
    p_purchase_token_hash, p_order_id, v_plan_id, v_payload, now()
  ) on conflict (purchase_token_hash) do update set
    purchase_state = case
      when public.monetization_purchases.purchase_state = 'refunded'
        then public.monetization_purchases.purchase_state
      else excluded.purchase_state
    end,
    order_id = coalesce(excluded.order_id, public.monetization_purchases.order_id),
    payload = public.monetization_purchases.payload || excluded.payload,
    verified_at = now();

  if v_should_reset_allowance then
    v_wallet := public.reset_monetization_allowance(v_binding.user_id);
  else
    v_wallet := public.ensure_monetization_wallet(v_binding.user_id);
    if p_status = 'grace'
      and p_expires_at is not null
      and (v_current.expires_at is null or p_expires_at > v_current.expires_at)
      and (
        v_wallet.period_ends_at is null
        or v_wallet.period_ends_at < p_expires_at
      ) then
      update public.monetization_wallets
      set period_ends_at = p_expires_at, updated_at = now()
      where user_id = v_binding.user_id
      returning * into v_wallet;
    end if;
  end if;
  return jsonb_build_object(
    'applied', true, 'handled', true, 'userId', v_binding.user_id,
    'planId', v_plan_id,
    'eventType', case when v_renewed then 'subscription_renewed'
      else 'subscription_' || p_status end,
    'creditsGranted', 0, 'remainingCredits', v_wallet.balance,
    'active', p_is_active, 'renewed', v_renewed
  );
end;
$$;

-- A voided purchase is terminal for the currently authoritative token. A
-- delayed Pub/Sub delivery must not be discarded behind a later status read.
create or replace function public.reconcile_google_play_voided_purchase(
  p_purchase_token_hash text,
  p_provider_event_time timestamptz,
  p_event_key text,
  p_order_id text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_purchase public.monetization_purchases;
  v_current public.monetization_subscription_statuses;
  v_wallet public.monetization_wallets;
  v_payload jsonb;
  v_event_count integer;
begin
  if p_provider_event_time is null then
    raise exception 'provider event time is required';
  end if;

  select * into v_binding
  from public.purchase_bindings
  where token_hash = p_purchase_token_hash
  for update;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'binding_not_found');
  end if;

  if p_event_key is not null and exists (
    select 1 from public.monetization_entitlement_events
    where event_key = p_event_key
  ) then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_binding.user_id
    );
  end if;

  select * into v_purchase
  from public.monetization_purchases
  where purchase_token_hash = p_purchase_token_hash
  for update;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'purchase_not_found');
  end if;

  select * into v_current
  from public.monetization_subscription_statuses
  where user_id = v_binding.user_id
  for update;
  v_payload := coalesce(p_payload, '{}'::jsonb) || jsonb_build_object(
    'providerEventTime', p_provider_event_time
  );

  if v_current.user_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash then
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, metadata
    ) values (
      v_binding.user_id, p_event_key, 'purchase_refunded_old_token',
      v_purchase.subscription_plan_id, v_purchase.product_id, false,
      p_provider_event_time, v_payload
    ) on conflict (event_key) do nothing;
    get diagnostics v_event_count = row_count;
    if p_event_key is not null and v_event_count = 0 then
      return jsonb_build_object(
        'applied', false, 'duplicate', true, 'handled', true,
        'userId', v_binding.user_id
      );
    end if;

    update public.monetization_purchases
    set purchase_state = 'refunded',
      order_id = coalesce(p_order_id, order_id),
      payload = payload || v_payload,
      verified_at = now()
    where id = v_purchase.id;
    return jsonb_build_object(
      'applied', false, 'handled', true, 'reason', 'old_token',
      'userId', v_binding.user_id, 'productId', v_purchase.product_id,
      'currentPreserved', true
    );
  end if;

  insert into public.monetization_entitlement_events (
    user_id, event_key, event_type, plan_id, product_id, is_active,
    effective_at, metadata
  ) values (
    v_binding.user_id, p_event_key, 'purchase_refunded',
    v_purchase.subscription_plan_id, v_purchase.product_id, false,
    p_provider_event_time, v_payload
  ) on conflict (event_key) do nothing;
  get diagnostics v_event_count = row_count;
  if p_event_key is not null and v_event_count = 0 then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_binding.user_id
    );
  end if;

  update public.monetization_purchases
  set purchase_state = 'refunded',
    order_id = coalesce(p_order_id, order_id),
    payload = payload || v_payload,
    verified_at = now()
  where id = v_purchase.id;

  update public.monetization_subscription_statuses
  set status = 'revoked',
    is_active = false,
    auto_renews = false,
    provider_event_time = greatest(provider_event_time, p_provider_event_time),
    metadata = metadata || v_payload,
    updated_at = now()
  where user_id = v_binding.user_id
    and purchase_token_hash = p_purchase_token_hash;

  v_wallet := public.reset_monetization_allowance(v_binding.user_id);
  return jsonb_build_object(
    'applied', true, 'handled', true, 'userId', v_binding.user_id,
    'productId', v_purchase.product_id, 'remainingCredits', v_wallet.balance,
    'active', false
  );
end;
$$;

-- Google can keep a subscription active through a silent grace period for at
-- least 24 hours without sending a grace RTDN. The local fallback waits out
-- that window; explicit Play terminal events still revoke immediately.
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
    where is_active = true
      and expires_at is not null
      and expires_at <= case
        when status = 'active' and auto_renews = true
          then now() - interval '24 hours'
        else now()
      end
    for update skip locked
  loop
    update public.monetization_subscription_statuses
    set status = 'expired', is_active = false, auto_renews = false,
      updated_at = now()
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
