-- Restore the database contracts that predate Phase 8 while preserving its
-- principal-bound allowance ledger and provider-recheck authority model.

alter function public.apply_monetization_allowance_grant(
  uuid, text, text, text, text, integer, integer, timestamptz
) rename to apply_monetization_allowance_grant_phase8_base;

revoke all on function public.apply_monetization_allowance_grant_phase8_base(
  uuid, text, text, text, text, integer, integer, timestamptz
) from public, anon, authenticated, service_role;

create function public.apply_monetization_allowance_grant(
  p_billing_principal_id uuid,
  p_purchase_token_hash text,
  p_order_id text,
  p_grant_cause text,
  p_event_key text,
  p_notification_type integer,
  p_credits integer,
  p_period_ends_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  v_result := public.apply_monetization_allowance_grant_phase8_base(
    p_billing_principal_id, p_purchase_token_hash, p_order_id,
    p_grant_cause, p_event_key, p_notification_type, p_credits,
    p_period_ends_at
  );

  -- creditsGranted describes the paid-period allowance. The separately stored
  -- balance_delta remains the actual ledger movement from free to paid state.
  if coalesce((v_result->>'granted')::boolean, false) then
    v_result := v_result || jsonb_build_object('creditsGranted', p_credits);
  end if;
  return v_result;
end;
$$;

revoke all on function public.apply_monetization_allowance_grant(
  uuid, text, text, text, text, integer, integer, timestamptz
) from public, anon, authenticated, service_role;
grant execute on function public.apply_monetization_allowance_grant(
  uuid, text, text, text, text, integer, integer, timestamptz
) to service_role;

create or replace function public.reset_monetization_allowance(p_user_id uuid)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_principal_id uuid;
  v_status public.monetization_subscription_statuses;
  v_wallet public.monetization_wallets;
  v_old_balance integer;
  v_silent_grace boolean := false;
begin
  v_principal_id := public.ensure_billing_principal(p_user_id);
  v_wallet := public.ensure_monetization_wallet_for_principal(v_principal_id);
  select * into v_status
  from public.monetization_subscription_statuses
  where billing_principal_id = v_principal_id
    and is_active = true
    and (
      expires_at is null
      or expires_at > now()
      or metadata->>'source' in ('client_verification', 'google_play_rtdn')
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
    and v_status.expires_at <= now()
    and v_status.expires_at > now() - interval '24 hours'
    and coalesce(v_status.metadata->>'source', 'unknown') not in (
      'client_verification', 'google_play_rtdn'
    );

  if found and v_status.is_active
    and v_status.plan_id in ('premium_monthly', 'premium_yearly') then
    if v_silent_grace then
      update public.monetization_wallets
      set period_credits = case v_status.plan_id
          when 'premium_monthly' then 300 else 360 end,
        tier = v_status.plan_id,
        period_ends_at = v_status.expires_at + interval '24 hours',
        updated_at = now()
      where billing_principal_id = v_principal_id
      returning * into v_wallet;
      return v_wallet;
    end if;

    return public.sync_monetization_wallet_authority(
      v_principal_id, v_status.plan_id, v_status.status, true,
      v_status.expires_at, 'paid-period-provider-required'
    );
  end if;

  if v_wallet.tier <> 'free' then
    v_wallet := public.sync_monetization_wallet_authority(
      v_principal_id, 'free', coalesce(v_status.status, 'free'), false,
      null, 'free-authority-sync'
    );
  end if;
  if v_wallet.period_ends_at is not null and v_wallet.period_ends_at > now() then
    return v_wallet;
  end if;

  v_old_balance := v_wallet.balance;
  update public.monetization_wallets
  set balance = bonus_balance + 20,
    allowance_remaining = 20,
    period_credits = 20,
    lifetime_earned = lifetime_earned
      + greatest((bonus_balance + 20) - v_old_balance, 0),
    tier = 'free', period_ends_at = now() + interval '1 day',
    updated_at = now()
  where billing_principal_id = v_principal_id
  returning * into v_wallet;
  if v_wallet.balance <> v_old_balance then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description
    ) values (
      v_principal_id, p_user_id, 'allowance_reset',
      v_wallet.balance - v_old_balance, v_wallet.balance,
      'system', 'Free allowance reset'
    );
  end if;
  return v_wallet;
end;
$$;

create or replace function public.sync_billing_principal_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.current_user_id is not distinct from old.current_user_id then
    return new;
  end if;
  if old.current_user_id is not null
    and new.current_user_id is null
    and new.retired_at is null then
    delete from public.planner_explanation_replays
    where user_id = old.current_user_id;
    delete from public.planner_explanation_quotes
    where user_id = old.current_user_id;
    update public.ai_usage_requests
    set user_id = null, response_payload = '{}'::jsonb,
      provider_request_id = null
    where billing_principal_id = new.billing_principal_id;
  end if;
  update public.purchase_bindings set user_id = new.current_user_id
  where billing_principal_id = new.billing_principal_id;
  update public.monetization_subscription_statuses
  set user_id = new.current_user_id
  where billing_principal_id = new.billing_principal_id;
  update public.monetization_wallets set user_id = new.current_user_id
  where billing_principal_id = new.billing_principal_id;
  update public.monetization_credit_transactions
  set user_id = null
  where billing_principal_id = new.billing_principal_id;
  update public.monetization_purchases set user_id = null
  where billing_principal_id = new.billing_principal_id;
  update public.monetization_entitlement_events
  set user_id = null
  where billing_principal_id = new.billing_principal_id;
  return new;
end;
$$;

alter function public.reconcile_google_play_subscription(
  text, text, text, boolean, boolean, text, timestamptz, timestamptz,
  text, jsonb
) rename to reconcile_google_play_subscription_phase8_base;

revoke all on function public.reconcile_google_play_subscription_phase8_base(
  text, text, text, boolean, boolean, text, timestamptz, timestamptz,
  text, jsonb
) from public, anon, authenticated, service_role;

create function public.reconcile_google_play_subscription(
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
security definer
set search_path = ''
as $$
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
        when 'chronospark_premium_annual' then 360
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

  return v_result;
end;
$$;

revoke all on function public.reconcile_google_play_subscription(
  text, text, text, boolean, boolean, text, timestamptz, timestamptz,
  text, jsonb
) from public, anon, authenticated, service_role;
grant execute on function public.reconcile_google_play_subscription(
  text, text, text, boolean, boolean, text, timestamptz, timestamptz,
  text, jsonb
) to service_role;

create or replace function public.expire_stale_monetization_subscriptions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.monetization_subscription_statuses;
  v_event_key text;
  v_local_expiry_count integer := 0;
  v_recheck_count integer := 0;
begin
  -- Explicit grace/cancellation authority ends at the paid-through time.
  -- Legacy active authority keeps the established 24-hour silent grace.
  for v_status in
    select * from public.monetization_subscription_statuses
    where is_active = true
      and expires_at is not null
      and expires_at <= now()
      and (
        status <> 'active'
        or auto_renews = false
        or (
          status = 'active'
          and auto_renews = true
          and coalesce(metadata->>'source', 'unknown') not in (
            'client_verification', 'google_play_rtdn'
          )
          and expires_at <= now() - interval '24 hours'
        )
      )
    for update skip locked
  loop
    v_event_key := 'expiry:' || v_status.billing_principal_id::text || ':' ||
      extract(epoch from v_status.expires_at)::bigint::text;

    update public.monetization_subscription_statuses
    set status = 'expired', is_active = false, auto_renews = false,
      updated_at = now()
    where billing_principal_id = v_status.billing_principal_id;

    perform public.sync_monetization_wallet_authority(
      v_status.billing_principal_id, v_status.plan_id, 'expired', false,
      v_status.expires_at, v_event_key
    );

    insert into public.monetization_entitlement_events (
      billing_principal_id, user_id, event_key, event_type, plan_id,
      product_id, is_active, effective_at, expires_at, metadata
    ) values (
      v_status.billing_principal_id, v_status.user_id, v_event_key,
      'subscription_expired', v_status.plan_id, v_status.product_id,
      false, now(), v_status.expires_at,
      jsonb_build_object('source', 'expiry_reconciliation')
    ) on conflict (event_key) do nothing;

    v_local_expiry_count := v_local_expiry_count + 1;
  end loop;

  -- Phase 8 provider-backed authority is never revoked from a local clock
  -- alone. Queue one idempotent provider recheck and keep entitlement active.
  insert into public.monetization_provider_recheck_queue (
    billing_principal_id, purchase_token_hash, product_id,
    provider_expires_at, state, reason, enqueued_at, updated_at
  )
  select status.billing_principal_id, status.purchase_token_hash,
    status.product_id, status.expires_at, 'pending',
    'stored_expiry_due', now(), now()
  from public.monetization_subscription_statuses status
  join public.billing_principals principal using (billing_principal_id)
  where status.status = 'active'
    and status.is_active = true
    and status.auto_renews = true
    and status.expires_at is not null
    and status.expires_at <= now()
    and status.purchase_token_hash is not null
    and status.metadata->>'source' in (
      'client_verification', 'google_play_rtdn'
    )
    and principal.retired_at is null
  on conflict (purchase_token_hash, provider_expires_at) do nothing;
  get diagnostics v_recheck_count = row_count;

  return v_local_expiry_count + v_recheck_count;
end;
$$;

revoke all on function public.expire_stale_monetization_subscriptions()
  from public, anon, authenticated, service_role;
grant execute on function public.expire_stale_monetization_subscriptions()
  to service_role;

-- Service jobs can inspect queued work, while RLS and explicit revokes keep
-- the queue hidden from client roles.
grant select on table public.monetization_provider_recheck_queue
  to service_role;

-- The immutable-lineage trigger remains the enforcement boundary. This
-- column grant lets that trigger execute and raise its stable P0001 contract.
grant update (predecessor_token_hash)
  on table public.purchase_bindings to service_role;
