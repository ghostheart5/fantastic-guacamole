-- Preserve the purchase RPC contract while making its duplicate-token lookup
-- unambiguous to PostgreSQL and the database function linter.
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
  from public.monetization_purchases as purchase
  where purchase.user_id = target_user_id
    and purchase.purchase_token_hash = apply_verified_purchase.purchase_token_hash
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

revoke all on function public.apply_verified_purchase(
  uuid, text, text, text, text, timestamptz, timestamptz, jsonb
) from public, anon, authenticated;
grant execute on function public.apply_verified_purchase(
  uuid, text, text, text, text, timestamptz, timestamptz, jsonb
) to service_role;
