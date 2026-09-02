-- Keep the authenticated credit-consumption RPC deterministic under PL/pgSQL's
-- output-column variable rules. Every wallet-column read is qualified so the
-- RETURNS TABLE column names cannot shadow persisted values.
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
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  wallet_row public.monetization_wallets;
  active_status public.monetization_subscription_statuses;
  bonus_used integer;
  allowance_used integer;
begin
  if current_user_id is null then
    raise exception 'auth required';
  end if;
  if credit_amount is null or credit_amount <= 0 or credit_amount > 1000 then
    raise exception 'credit amount must be between 1 and 1000';
  end if;
  if reason is null or btrim(reason) = '' or char_length(reason) > 160 then
    raise exception 'reason must be between 1 and 160 characters';
  end if;
  if metadata is null or jsonb_typeof(metadata) <> 'object' or
      pg_column_size(metadata) > 8192 then
    raise exception 'metadata must be an object no larger than 8192 bytes';
  end if;

  insert into public.monetization_wallets (
    user_id, balance, allowance_remaining, bonus_balance, period_credits,
    lifetime_earned, lifetime_spent, tier, period_ends_at, updated_at
  )
  values (
    current_user_id, 20, 20, 0, 20, 20, 0, 'free', now() + interval '1 day', now()
  )
  on conflict (user_id) do nothing;

  select mw.* into wallet_row
  from public.monetization_wallets as mw
  where mw.user_id = current_user_id
  for update;

  if wallet_row.period_ends_at is not null and wallet_row.period_ends_at <= now() then
    select subscription.* into active_status
    from public.monetization_subscription_statuses as subscription
    where subscription.user_id = current_user_id
      and subscription.is_active = true
      and (subscription.expires_at is null or subscription.expires_at > now())
    order by subscription.updated_at desc
    limit 1;

    update public.monetization_wallets as mw
    set tier = case active_status.plan_id
          when 'premium_monthly' then 'premium_monthly'
          when 'premium_yearly' then 'premium_yearly'
          when 'lifetime' then 'lifetime'
          else 'free'
        end,
        period_credits = case active_status.plan_id
          when 'premium_monthly' then 250
          when 'premium_yearly' then 4000
          when 'lifetime' then 0
          else 20
        end,
        allowance_remaining = case active_status.plan_id
          when 'premium_monthly' then 250
          when 'premium_yearly' then 4000
          when 'lifetime' then 0
          else 20
        end,
        balance = mw.bonus_balance + case active_status.plan_id
          when 'premium_monthly' then 250
          when 'premium_yearly' then 4000
          when 'lifetime' then 0
          else 20
        end,
        period_ends_at = case active_status.plan_id
          when 'premium_monthly' then coalesce(active_status.expires_at, now() + interval '30 days')
          when 'premium_yearly' then coalesce(active_status.expires_at, now() + interval '365 days')
          when 'lifetime' then null
          else now() + interval '1 day'
        end,
        updated_at = now()
    where mw.user_id = current_user_id
    returning mw.* into wallet_row;
  end if;

  if wallet_row.balance < credit_amount then
    raise exception 'insufficient credits';
  end if;

  bonus_used := least(wallet_row.bonus_balance, credit_amount);
  allowance_used := credit_amount - bonus_used;

  update public.monetization_wallets as mw
  set bonus_balance = mw.bonus_balance - bonus_used,
      allowance_remaining = greatest(mw.allowance_remaining - allowance_used, 0),
      balance = mw.balance - credit_amount,
      lifetime_spent = mw.lifetime_spent + credit_amount,
      updated_at = now()
  where mw.user_id = current_user_id
  returning mw.* into wallet_row;

  insert into public.monetization_credit_transactions (
    user_id, type, amount, balance_after, source, description, metadata
  )
  values (
    current_user_id, 'spend', -credit_amount, wallet_row.balance,
    'app', reason, metadata
  );

  return query
  select true, wallet_row.balance, wallet_row.allowance_remaining,
         wallet_row.bonus_balance, wallet_row.period_credits,
         wallet_row.lifetime_earned, wallet_row.lifetime_spent,
         wallet_row.tier, wallet_row.updated_at, wallet_row.period_ends_at;
end;
$$;

revoke all on function public.consume_monetization_credits(integer, text, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.consume_monetization_credits(integer, text, jsonb)
  to authenticated;

-- The server-only purchase RPC has an input named purchase_token_hash and a
-- table column with the same name. Qualify every lookup column so the receipt
-- idempotency check cannot be rejected as ambiguous.
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
set search_path = ''
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

  select purchase.* into existing_purchase
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

  select subscription.* into current_status
  from public.monetization_subscription_statuses as subscription
  where subscription.user_id = target_user_id
  limit 1;

  if product_id = 'chronospark_premium_monthly' then
    resolved_plan_id := 'premium_monthly';
    event_type := case
      when current_status.user_id is not null
        and current_status.expires_at is not null
        and expires_at is not null
        and expires_at > current_status.expires_at
        then 'subscription_renewed'
      else 'subscription_started'
    end;

    insert into public.monetization_subscription_statuses (
      user_id, plan_id, product_id, status, is_active, source, auto_renews,
      period_credits, started_at, expires_at, order_id, purchase_token_hash,
      metadata, updated_at
    )
    values (
      target_user_id, resolved_plan_id, product_id, 'active', true,
      'google_play', true, 250,
      coalesce(current_status.started_at, verified_at), expires_at, order_id,
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
          started_at = coalesce(
            public.monetization_subscription_statuses.started_at,
            excluded.started_at
          ),
          expires_at = excluded.expires_at,
          order_id = excluded.order_id,
          purchase_token_hash = excluded.purchase_token_hash,
          metadata = excluded.metadata,
          updated_at = now();

    perform public.reset_monetization_allowance(target_user_id);
    select wallet.* into wallet_row
    from public.monetization_wallets as wallet
    where wallet.user_id = target_user_id;

    insert into public.monetization_credit_transactions (
      user_id, type, amount, balance_after, source, description, metadata
    )
    values (
      target_user_id, 'subscription_grant', 250, wallet_row.balance,
      'google_play', 'Premium monthly credits applied',
      jsonb_build_object('product_id', product_id, 'event_type', event_type)
    );
  elsif product_id = 'chronospark_premium_annual' then
    resolved_plan_id := 'premium_yearly';
    event_type := case
      when current_status.user_id is not null
        and current_status.expires_at is not null
        and expires_at is not null
        and expires_at > current_status.expires_at
        then 'subscription_renewed'
      else 'subscription_started'
    end;

    insert into public.monetization_subscription_statuses (
      user_id, plan_id, product_id, status, is_active, source, auto_renews,
      period_credits, started_at, expires_at, order_id, purchase_token_hash,
      metadata, updated_at
    )
    values (
      target_user_id, resolved_plan_id, product_id, 'active', true,
      'google_play', true, 4000,
      coalesce(current_status.started_at, verified_at), expires_at, order_id,
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
          started_at = coalesce(
            public.monetization_subscription_statuses.started_at,
            excluded.started_at
          ),
          expires_at = excluded.expires_at,
          order_id = excluded.order_id,
          purchase_token_hash = excluded.purchase_token_hash,
          metadata = excluded.metadata,
          updated_at = now();

    perform public.reset_monetization_allowance(target_user_id);
    select wallet.* into wallet_row
    from public.monetization_wallets as wallet
    where wallet.user_id = target_user_id;

    insert into public.monetization_credit_transactions (
      user_id, type, amount, balance_after, source, description, metadata
    )
    values (
      target_user_id, 'subscription_grant', 4000, wallet_row.balance,
      'google_play', 'Premium yearly credits applied',
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
      target_user_id, resolved_plan_id, product_id, 'active', true,
      'google_play', false, 0,
      coalesce(current_status.started_at, verified_at), null, order_id,
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
          started_at = coalesce(
            public.monetization_subscription_statuses.started_at,
            excluded.started_at
          ),
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

    update public.monetization_wallets as wallet
    set tier = 'lifetime',
        period_credits = 0,
        allowance_remaining = 0,
        balance = wallet.bonus_balance,
        period_ends_at = null,
        updated_at = now()
    where wallet.user_id = target_user_id
    returning wallet.* into wallet_row;
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
    user_id, product_id, purchase_type, platform, purchase_state,
    purchase_token_hash, order_id, credits_granted, subscription_plan_id,
    payload, verified_at
  )
  values (
    target_user_id, product_id, purchase_type, 'google_play', 'verified',
    purchase_token_hash, order_id, credits_to_grant, resolved_plan_id,
    payload, verified_at
  );

  insert into public.monetization_entitlement_events (
    user_id, event_type, plan_id, product_id, is_active, effective_at,
    expires_at, metadata
  )
  values (
    target_user_id, coalesce(event_type, 'subscription_started'),
    resolved_plan_id, product_id, resolved_plan_id is not null, verified_at,
    expires_at, payload
  );

  if wallet_row.user_id is null then
    select wallet.* into wallet_row
    from public.monetization_wallets as wallet
    where wallet.user_id = target_user_id;
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

;
