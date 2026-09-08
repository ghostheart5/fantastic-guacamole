-- Repair the observed missing allowance for a completed internal prepaid test.
-- No existing wallet or grant row is rewritten. Activation still requires
-- immutable account binding and Google authority; ordinary plans are unchanged.
alter table public.monetization_allowance_grants
  drop constraint monetization_allowance_grants_grant_cause_check,
  add constraint monetization_allowance_grants_grant_cause_check check (
    grant_cause in ('legacy_snapshot', 'initial_activation', 'rtdn_renewal',
      'resubscription_activation', 'recovery_activation', 'prepaid_activation')
  );
alter table public.monetization_allowance_grants
  drop constraint monetization_allowance_grants_cause_check,
  add constraint monetization_allowance_grants_cause_check check (
    (grant_cause = 'legacy_snapshot' and notification_type is null)
    or (
      grant_cause = 'initial_activation'
      and order_id is not null
      and notification_type is null
    )
    or (
      grant_cause = 'rtdn_renewal'
      and order_id is not null
      and notification_type = 2
    )
    or (
      grant_cause in ('resubscription_activation', 'prepaid_activation')
      and order_id is not null
      and (notification_type is null or notification_type = 4)
    )
    or (
      grant_cause = 'recovery_activation'
      and order_id is not null
      and (
        notification_type is null
        or notification_type in (1, 4)
      )
    )
  );

create unique index monetization_allowance_grants_prepaid_token_idx
  on public.monetization_allowance_grants (purchase_token_hash)
  where grant_cause = 'prepaid_activation';

create or replace function public.apply_monetization_allowance_grant(
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
security invoker
set search_path = ''
as $$
declare
  v_order_id text := nullif(btrim(p_order_id), '');
  v_grant_id bigint;
  v_wallet public.monetization_wallets;
  v_old_balance integer;
  v_delta integer;
  v_user_id uuid;
  v_predecessor_token_hash text;
begin
  if p_purchase_token_hash is null
    or p_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or v_order_id is null
    or nullif(btrim(p_event_key), '') is null
    or char_length(p_event_key) > 500
    or p_credits <= 0
    or p_grant_cause not in (
      'initial_activation', 'rtdn_renewal', 'resubscription_activation',
      'recovery_activation', 'prepaid_activation'
    )
    or (p_grant_cause = 'initial_activation' and p_notification_type is not null)
    or (p_grant_cause = 'rtdn_renewal' and p_notification_type <> 2)
    or (
      p_grant_cause in ('resubscription_activation', 'prepaid_activation')
      and p_notification_type is not null
      and p_notification_type <> 4
    )
    or (
      p_grant_cause = 'recovery_activation'
      and p_notification_type is not null
      and p_notification_type not in (1, 4)
    ) then
    return jsonb_build_object(
      'granted', false, 'reason', 'invalid_grant_cause', 'creditsGranted', 0
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:order:' || v_order_id, 0)
  );
  perform public.ensure_monetization_wallet_for_principal(
    p_billing_principal_id
  );

  if exists (
    select 1 from public.monetization_allowance_grants
    where order_id = v_order_id
  ) then
    return jsonb_build_object(
      'granted', false, 'reason', 'duplicate_order_id', 'creditsGranted', 0
    );
  end if;
  if p_grant_cause = 'initial_activation' and exists (
    select 1 from public.monetization_allowance_grants
    where billing_principal_id = p_billing_principal_id
  ) then
    return jsonb_build_object(
      'granted', false, 'reason', 'initial_already_granted',
      'creditsGranted', 0
    );
  end if;
  if p_grant_cause in (
    'resubscription_activation', 'recovery_activation'
  ) then
    select predecessor_token_hash into v_predecessor_token_hash
    from public.purchase_bindings
    where token_hash = p_purchase_token_hash;
    if p_grant_cause = 'resubscription_activation'
      and v_predecessor_token_hash is null then
      return jsonb_build_object(
        'granted', false, 'reason', 'resubscription_lineage_missing',
        'creditsGranted', 0
      );
    end if;
    if p_grant_cause = 'recovery_activation'
      and p_notification_type is distinct from 1
      and v_predecessor_token_hash is null then
      return jsonb_build_object(
        'granted', false, 'reason', 'recovery_lineage_missing',
        'creditsGranted', 0
      );
    end if;
  end if;

  insert into public.monetization_allowance_grants (
    billing_principal_id, purchase_token_hash, order_id, grant_cause,
    event_key, notification_type, credits, period_ends_at,
    metadata
  ) values (
    p_billing_principal_id, p_purchase_token_hash, v_order_id,
    p_grant_cause, p_event_key, p_notification_type, p_credits,
    p_period_ends_at, jsonb_strip_nulls(jsonb_build_object(
      'source', 'google_play',
      'predecessorTokenHash', v_predecessor_token_hash
    ))
  ) on conflict do nothing
  returning id into v_grant_id;
  if v_grant_id is null then
    return jsonb_build_object(
      'granted', false, 'reason', 'grant_duplicate', 'creditsGranted', 0
    );
  end if;

  select balance into v_old_balance from public.monetization_wallets
  where billing_principal_id = p_billing_principal_id for update;
  update public.monetization_wallets
  set balance = bonus_balance + p_credits,
    allowance_remaining = p_credits,
    period_credits = p_credits,
    lifetime_earned = lifetime_earned
      + greatest((bonus_balance + p_credits) - v_old_balance, 0),
    tier = case p_credits when 300 then 'premium_monthly'
      when 360 then 'premium_yearly' else tier end,
    period_ends_at = p_period_ends_at,
    updated_at = now()
  where billing_principal_id = p_billing_principal_id
  returning * into v_wallet;
  v_delta := v_wallet.balance - v_old_balance;
  update public.monetization_allowance_grants
  set balance_delta = v_delta where id = v_grant_id;
  select current_user_id into v_user_id from public.billing_principals
  where billing_principal_id = p_billing_principal_id;
  if v_delta <> 0 then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description, metadata
    ) values (
      p_billing_principal_id, v_user_id, 'allowance_grant', v_delta,
      v_wallet.balance, 'google_play', 'Provider-confirmed allowance grant',
      jsonb_build_object(
        'grantCause', p_grant_cause, 'orderId', v_order_id,
        'eventKey', p_event_key
      )
    );
  end if;
  return jsonb_build_object(
    'granted', true, 'reason', 'granted',
    'creditsGranted', greatest(v_delta, 0),
    'allowance', p_credits, 'balance', v_wallet.balance
  );
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
security definer
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_current_binding public.purchase_bindings;
  v_principal public.billing_principals;
  v_current public.monetization_subscription_statuses;
  v_purchase public.monetization_purchases;
  v_plan_id text;
  v_period_credits integer;
  v_wallet public.monetization_wallets;
  v_payload jsonb;
  v_source text;
  v_order_id text := nullif(btrim(p_order_id), '');
  v_notification_type integer;
  v_event_count integer;
  v_incoming_is_predecessor boolean := false;
  v_current_is_predecessor boolean := false;
  v_grant jsonb := jsonb_build_object(
    'granted', false, 'reason', 'not_paid_grant_cause', 'creditsGranted', 0
  );
  v_grant_cause text;
  v_event_type text;
  v_is_lapsed_resubscription boolean := false;
  v_is_late_lapsed_resubscription boolean := false;
  v_is_same_token_recovery boolean := false;
  v_is_hold_repurchase boolean := false;
  v_is_paid_recovery boolean := false;
begin
  if p_purchase_token_hash is null
    or p_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or p_status is null
    or p_status not in ('pending', 'active', 'grace', 'on_hold', 'paused',
      'canceled', 'expired', 'revoked')
    or p_is_active is null
    or p_auto_renews is null
    or nullif(btrim(p_event_key), '') is null
    or char_length(p_event_key) > 500 then
    raise exception 'unsupported subscription authority';
  end if;
  if p_provider_event_time is null then
    raise exception 'provider event time is required';
  end if;
  if p_status in ('expired', 'revoked')
    and (p_is_active or p_auto_renews) then
    raise exception 'terminal subscription authority cannot be active';
  end if;

  select * into v_binding from public.purchase_bindings
  where token_hash = p_purchase_token_hash for update;
  if not found or v_binding.product_id <> p_product_id then
    return jsonb_build_object('applied', false, 'reason', 'binding_not_found');
  end if;
  select * into v_principal from public.billing_principals
  where billing_principal_id = v_binding.billing_principal_id for update;
  if not found or v_principal.retired_at is not null then
    return jsonb_build_object('applied', false, 'reason', 'principal_unavailable');
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
  v_source := coalesce(v_payload->>'source', 'unknown');
  if jsonb_typeof(v_payload->'notificationType') = 'number' then
    v_notification_type := (v_payload->>'notificationType')::integer;
  elsif jsonb_typeof(v_payload->'notificationType') = 'string'
    and (v_payload->>'notificationType') ~ '^[0-9]+$' then
    v_notification_type := (v_payload->>'notificationType')::integer;
  end if;

  select * into v_current from public.monetization_subscription_statuses
  where billing_principal_id = v_binding.billing_principal_id for update;
  if v_current.billing_principal_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash then
    select * into v_current_binding from public.purchase_bindings
    where token_hash = v_current.purchase_token_hash;
    with recursive current_ancestry(token_hash, path) as (
      select v_current.purchase_token_hash, array[v_current.purchase_token_hash]
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
      select 1 from current_ancestry where token_hash = p_purchase_token_hash
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
  select * into v_purchase from public.monetization_purchases
  where purchase_token_hash = p_purchase_token_hash for update;

  v_is_lapsed_resubscription := p_status = 'active'
    and p_is_active
    and v_order_id is not null
    and v_current.billing_principal_id is not null
    and v_current.status = 'expired'
    and not v_current.is_active
    and v_current.metadata->>'source' = 'google_play_rtdn'
    and v_current.metadata->>'notificationType' = '13'
    and v_current.expires_at is not null
    and v_current.expires_at <= p_provider_event_time
    and v_current.provider_event_time < p_provider_event_time
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash
    and v_binding.predecessor_token_hash = v_current.purchase_token_hash
    and (
      v_source = 'client_verification'
      or (
        v_source = 'google_play_rtdn'
        and v_notification_type = 4
      )
    );

  v_is_late_lapsed_resubscription := p_status = 'expired'
    and not p_is_active
    and v_source = 'google_play_rtdn'
    and v_notification_type = 13
    and v_current.billing_principal_id is not null
    and v_current.is_active
    and v_current.status = 'active'
    and v_current.order_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash
    and v_incoming_is_predecessor
    and v_current_binding.predecessor_token_hash = p_purchase_token_hash
    and v_current.metadata->>'lineageSource' = 'out_of_app_resubscribe'
    and p_expires_at is not null
    and p_expires_at <= v_current.provider_event_time
    and (
      v_current.metadata->>'source' = 'client_verification'
      or (
        v_current.metadata->>'source' = 'google_play_rtdn'
        and v_current.metadata->>'notificationType' = '4'
      )
    );

  v_is_same_token_recovery := p_status = 'active'
    and p_is_active
    and v_order_id is not null
    and v_source = 'google_play_rtdn'
    and v_notification_type = 1
    and v_current.billing_principal_id is not null
    and not v_current.is_active
    and v_current.status in ('on_hold', 'paused')
    and v_current.purchase_token_hash = p_purchase_token_hash
    and v_current.order_id is distinct from v_order_id
    and v_current.provider_event_time < p_provider_event_time
    and p_expires_at is not null
    and (
      v_current.expires_at is null
      or p_expires_at > v_current.expires_at
    );

  v_is_hold_repurchase := p_status = 'active'
    and p_is_active
    and v_order_id is not null
    and v_current.billing_principal_id is not null
    and not v_current.is_active
    and v_current.status in ('on_hold', 'paused')
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash
    and v_binding.predecessor_token_hash = v_current.purchase_token_hash
    and v_current_is_predecessor
    and v_current.provider_event_time < p_provider_event_time
    and p_expires_at is not null
    and p_expires_at > p_provider_event_time
    and (
      v_source = 'client_verification'
      or (
        v_source = 'google_play_rtdn'
        and v_notification_type = 4
      )
    );
  v_is_paid_recovery := v_is_same_token_recovery or v_is_hold_repurchase;

  if v_current.billing_principal_id is not null
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
      billing_principal_id, user_id, event_key, event_type, plan_id,
      product_id, is_active, effective_at, expires_at, metadata
    ) values (
      v_binding.billing_principal_id, v_principal.current_user_id, p_event_key,
      'subscription_' || p_status || '_old_token', v_plan_id, p_product_id,
      p_is_active, p_provider_event_time, p_expires_at, v_payload
    ) on conflict (event_key) do nothing;
    insert into public.monetization_purchases (
      billing_principal_id, user_id, product_id, purchase_type,
      purchase_state, purchase_token_hash, order_id,
      subscription_plan_id, payload, verified_at
    ) values (
      v_binding.billing_principal_id, v_principal.current_user_id,
      p_product_id, 'subscription', p_status, p_purchase_token_hash,
      v_order_id, v_plan_id, v_payload, now()
    ) on conflict (purchase_token_hash) do update set
      purchase_state = case
        when public.monetization_purchases.purchase_state in (
          'refunded', 'revoked'
        )
          then public.monetization_purchases.purchase_state
        else excluded.purchase_state end,
      order_id = coalesce(excluded.order_id, public.monetization_purchases.order_id),
      payload = public.monetization_purchases.payload || excluded.payload,
      verified_at = now();
    perform public.complete_monetization_provider_rechecks(
      p_purchase_token_hash, p_provider_event_time, 'old_token'
    );
    if v_is_late_lapsed_resubscription then
      v_grant_cause := 'resubscription_activation';
      v_grant := public.apply_monetization_allowance_grant(
        v_binding.billing_principal_id, v_current.purchase_token_hash,
        v_current.order_id, v_grant_cause, p_event_key,
        case
          when v_current.metadata->>'source' = 'google_play_rtdn' then 4
          else null
        end,
        v_current.period_credits, v_current.expires_at
      );
      if (v_grant->>'granted')::boolean then
        update public.monetization_entitlement_events
        set event_type = 'subscription_resubscribed_late_expiry',
          metadata = metadata || jsonb_build_object(
            'allowanceGrantCause', v_grant_cause,
            'allowanceOrderId', v_current.order_id,
            'successorPurchaseTokenHash', v_current.purchase_token_hash
          )
        where event_key = p_event_key;
      end if;
    end if;
    return jsonb_build_object(
      'applied', false, 'handled', true, 'reason', 'old_token',
      'userId', v_principal.current_user_id,
      'active', v_current.is_active,
      'creditsGranted', coalesce((v_grant->>'creditsGranted')::integer, 0),
      'resubscribed', coalesce(
        v_grant_cause = 'resubscription_activation'
          and (v_grant->>'granted')::boolean,
        false
      )
    );
  end if;

  -- Terminal authority is evaluated before event-key dedupe.
  if (
    v_current.billing_principal_id is not null
    and v_current.purchase_token_hash is not distinct from p_purchase_token_hash
    and v_current.status = 'revoked'
  ) or v_purchase.purchase_state in ('refunded', 'revoked') then
    insert into public.monetization_entitlement_events (
      billing_principal_id, user_id, event_key, event_type, plan_id,
      product_id, is_active, effective_at, expires_at, metadata
    ) values (
      v_binding.billing_principal_id, v_principal.current_user_id, p_event_key,
      'subscription_terminal_token_ignored', v_plan_id, p_product_id,
      false, p_provider_event_time, p_expires_at, v_payload
    ) on conflict (event_key) do nothing;
    perform public.complete_monetization_provider_rechecks(
      p_purchase_token_hash, p_provider_event_time, 'terminal_preserved'
    );
    return jsonb_build_object(
      'applied', false, 'handled', true, 'reason', 'terminal_token',
      'userId', v_principal.current_user_id, 'active', false,
      'creditsGranted', 0
    );
  end if;

  if p_event_key is not null and exists (
    select 1 from public.monetization_entitlement_events
    where event_key = p_event_key
  ) then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_principal.current_user_id, 'creditsGranted', 0
    );
  end if;
  if v_current.billing_principal_id is not null and (
    v_current.provider_event_time > p_provider_event_time
    or (
      v_current.provider_event_time = p_provider_event_time
      and not v_current.is_active and p_is_active
      and not (
        p_expires_at is not null and v_current.expires_at is not null
        and p_expires_at > v_current.expires_at
      )
    )
  ) then
    insert into public.monetization_entitlement_events (
      billing_principal_id, user_id, event_key, event_type, plan_id,
      product_id, is_active, effective_at, expires_at, metadata
    ) values (
      v_binding.billing_principal_id, v_principal.current_user_id, p_event_key,
      'subscription_stale_ignored', v_plan_id, p_product_id, p_is_active,
      p_provider_event_time, p_expires_at, v_payload
    ) on conflict (event_key) do nothing;
    return jsonb_build_object(
      'applied', false, 'handled', true, 'stale', true,
      'reason', 'stale_event', 'userId', v_principal.current_user_id,
      'creditsGranted', 0
    );
  end if;

  v_event_type := 'subscription_' || p_status;
  insert into public.monetization_entitlement_events (
    billing_principal_id, user_id, event_key, event_type, plan_id,
    product_id, is_active, effective_at, expires_at, metadata
  ) values (
    v_binding.billing_principal_id, v_principal.current_user_id, p_event_key,
    v_event_type, v_plan_id, p_product_id, p_is_active,
    p_provider_event_time, p_expires_at, v_payload
  ) on conflict (event_key) do nothing;
  get diagnostics v_event_count = row_count;
  if p_event_key is not null and v_event_count = 0 then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_principal.current_user_id, 'creditsGranted', 0
    );
  end if;

  insert into public.monetization_subscription_statuses (
    billing_principal_id, user_id, plan_id, product_id, status,
    is_active, auto_renews, period_credits, started_at, expires_at,
    order_id, purchase_token_hash, provider_event_time, metadata, updated_at
  ) values (
    v_binding.billing_principal_id, v_principal.current_user_id,
    v_plan_id, p_product_id, p_status, p_is_active, p_auto_renews,
    v_period_credits, coalesce(v_current.started_at, now()), p_expires_at,
    v_order_id, p_purchase_token_hash, p_provider_event_time, v_payload, now()
  ) on conflict (billing_principal_id) do update set
    user_id = excluded.user_id, plan_id = excluded.plan_id,
    product_id = excluded.product_id, status = excluded.status,
    is_active = excluded.is_active, auto_renews = excluded.auto_renews,
    period_credits = excluded.period_credits,
    started_at = coalesce(
      public.monetization_subscription_statuses.started_at,
      excluded.started_at
    ),
    expires_at = excluded.expires_at,
    order_id = coalesce(excluded.order_id,
      public.monetization_subscription_statuses.order_id),
    purchase_token_hash = excluded.purchase_token_hash,
    provider_event_time = greatest(
      public.monetization_subscription_statuses.provider_event_time,
      excluded.provider_event_time
    ),
    metadata = excluded.metadata, updated_at = now();

  insert into public.monetization_purchases (
    billing_principal_id, user_id, product_id, purchase_type,
    purchase_state, purchase_token_hash, order_id,
    subscription_plan_id, payload, verified_at
  ) values (
    v_binding.billing_principal_id, v_principal.current_user_id,
    p_product_id, 'subscription', p_status, p_purchase_token_hash,
    v_order_id, v_plan_id, v_payload, now()
  ) on conflict (purchase_token_hash) do update set
    user_id = excluded.user_id,
    purchase_state = case
      when public.monetization_purchases.purchase_state in (
        'refunded', 'revoked'
      )
        then public.monetization_purchases.purchase_state
      else excluded.purchase_state end,
    order_id = coalesce(excluded.order_id, public.monetization_purchases.order_id),
    payload = public.monetization_purchases.payload || excluded.payload,
    verified_at = now();

  v_wallet := public.sync_monetization_wallet_authority(
    v_binding.billing_principal_id, v_plan_id, p_status, p_is_active,
    p_expires_at, p_event_key
  );

  -- Internal prepaid testing only. Every field below is supplied by the
  -- server's Google lookup, never by the app's purchase request.
  if p_status = 'active' and p_is_active and v_order_id is not null
    and not p_auto_renews
    and p_product_id = 'chronospark_premium_monthly'
    and v_payload->>'basePlanId' = 'monthly-prepaid-test'
    and v_payload->>'prepaidPlan' = 'true'
    and v_payload->>'testPurchase' = 'true'
    and (v_source = 'client_verification'
      or (v_source = 'google_play_rtdn' and v_notification_type = 4)) then
    v_grant_cause := 'prepaid_activation';
    v_grant := public.apply_monetization_allowance_grant(
      v_binding.billing_principal_id, p_purchase_token_hash, v_order_id,
      v_grant_cause, p_event_key,
      case when v_source = 'google_play_rtdn' then 4 else null end,
      v_period_credits, p_expires_at
    );
  elsif p_status = 'active' and p_is_active and v_order_id is not null
    and v_source = 'google_play_rtdn' and v_notification_type = 2 then
    v_grant_cause := 'rtdn_renewal';
    v_grant := public.apply_monetization_allowance_grant(
      v_binding.billing_principal_id, p_purchase_token_hash, v_order_id,
      v_grant_cause, p_event_key, 2, v_period_credits, p_expires_at
    );
  elsif v_is_paid_recovery then
    v_grant_cause := 'recovery_activation';
    v_grant := public.apply_monetization_allowance_grant(
      v_binding.billing_principal_id, p_purchase_token_hash, v_order_id,
      v_grant_cause, p_event_key,
      case
        when v_source = 'google_play_rtdn' then v_notification_type
        else null
      end,
      v_period_credits, p_expires_at
    );
  elsif v_is_lapsed_resubscription then
    v_grant_cause := 'resubscription_activation';
    v_grant := public.apply_monetization_allowance_grant(
      v_binding.billing_principal_id, p_purchase_token_hash, v_order_id,
      v_grant_cause, p_event_key,
      case when v_source = 'google_play_rtdn' then 4 else null end,
      v_period_credits, p_expires_at
    );
  elsif p_status = 'active' and p_is_active and v_order_id is not null
    and v_source = 'client_verification'
    and not exists (
      select 1 from public.monetization_allowance_grants
      where billing_principal_id = v_binding.billing_principal_id
    ) then
    v_grant_cause := 'initial_activation';
    v_grant := public.apply_monetization_allowance_grant(
      v_binding.billing_principal_id, p_purchase_token_hash, v_order_id,
      v_grant_cause, p_event_key, null, v_period_credits, p_expires_at
    );
  elsif p_status = 'active' and p_is_active
    and v_source = 'google_play_rtdn' and v_notification_type = 2
    and v_order_id is null then
    v_grant := jsonb_build_object(
      'granted', false, 'reason', 'missing_order_id', 'creditsGranted', 0
    );
  end if;

  if (v_grant->>'granted')::boolean then
    v_event_type := case v_grant_cause
      when 'rtdn_renewal' then 'subscription_renewed'
      when 'recovery_activation' then 'subscription_recovered'
      when 'resubscription_activation' then 'subscription_resubscribed'
      else 'subscription_activated'
    end;
    update public.monetization_entitlement_events
    set event_type = v_event_type,
      metadata = metadata || jsonb_build_object(
        'allowanceGrantCause', v_grant_cause,
        'allowanceOrderId', v_order_id
      )
    where event_key = p_event_key;
    select * into v_wallet from public.monetization_wallets
    where billing_principal_id = v_binding.billing_principal_id;
  end if;
  perform public.complete_monetization_provider_rechecks(
    p_purchase_token_hash, p_provider_event_time, p_status
  );
  return jsonb_build_object(
    'applied', true, 'handled', true,
    'userId', v_principal.current_user_id,
    'billingPrincipalId', v_binding.billing_principal_id,
    'planId', v_plan_id, 'eventType', v_event_type,
    'creditsGranted', coalesce((v_grant->>'creditsGranted')::integer, 0),
    'allowanceGrantReason', v_grant->>'reason',
    'remainingCredits', v_wallet.balance,
    'active', p_is_active,
    'renewed', coalesce(v_grant_cause = 'rtdn_renewal'
      and (v_grant->>'granted')::boolean, false),
    'recovered', coalesce(v_grant_cause = 'recovery_activation'
      and (v_grant->>'granted')::boolean, false),
    'resubscribed', coalesce(v_grant_cause = 'resubscription_activation'
      and (v_grant->>'granted')::boolean, false)
  );
end;
$$;
