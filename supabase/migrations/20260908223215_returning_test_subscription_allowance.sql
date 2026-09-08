-- Fix the observed returning license tester purchase without rewriting balances.
alter table public.monetization_allowance_grants
  drop constraint monetization_allowance_grants_grant_cause_check,
  add constraint monetization_allowance_grants_grant_cause_check check (
    grant_cause in ('legacy_snapshot', 'initial_activation', 'rtdn_renewal',
      'resubscription_activation', 'recovery_activation', 'prepaid_activation', 'purchase_activation')
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
      grant_cause in ('resubscription_activation', 'prepaid_activation', 'purchase_activation')
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

create unique index monetization_allowance_grants_purchase_token_idx on public.monetization_allowance_grants(purchase_token_hash) where grant_cause='purchase_activation';
create or replace function public.apply_monetization_allowance_grant_phase8_base(
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
      'recovery_activation', 'prepaid_activation', 'purchase_activation'
    )
    or (p_grant_cause = 'initial_activation' and p_notification_type is not null)
    or (p_grant_cause = 'rtdn_renewal' and p_notification_type <> 2)
    or (
      p_grant_cause in ('resubscription_activation', 'prepaid_activation', 'purchase_activation')
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


alter function public.reconcile_google_play_subscription(text,text,text,boolean,boolean,text,timestamptz,timestamptz,text,jsonb)
 rename to reconcile_google_play_subscription_monthly_base;
revoke all on function public.reconcile_google_play_subscription_monthly_base(text,text,text,boolean,boolean,text,timestamptz,timestamptz,text,jsonb) from public,anon,authenticated;
create function public.reconcile_google_play_subscription(
 p_purchase_token_hash text,p_product_id text,p_status text,p_is_active boolean,
 p_auto_renews boolean,p_order_id text,p_expires_at timestamptz,
 p_provider_event_time timestamptz,p_event_key text,p_payload jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb; g jsonb; b public.purchase_bindings; w public.monetization_wallets;
begin
 r:=public.reconcile_google_play_subscription_monthly_base(p_purchase_token_hash,p_product_id,p_status,p_is_active,p_auto_renews,p_order_id,p_expires_at,p_provider_event_time,p_event_key,p_payload);
 -- A verified fresh auto-renewing test purchase can follow an unrelated,
 -- expired token. It need not have Google's optional predecessor lineage.
 -- Never infer a paid purchase from a wallet read, grace, or generic refresh.
 if coalesce((r->>'applied')::boolean,false) and p_status='active' and p_is_active
  and p_auto_renews and p_expires_at>now() and nullif(btrim(p_order_id),'') is not null
  and p_payload->>'testPurchase'='true' and p_payload->>'prepaidPlan'='false'
  and ((p_product_id='chronospark_premium_monthly' and p_payload->>'basePlanId'='monthly')
    or (p_product_id='chronospark_premium_annual' and p_payload->>'basePlanId'='annual'))
  and (p_payload->>'source'='client_verification'
    or (p_payload->>'source'='google_play_rtdn' and p_payload->>'notificationType'='4')) then
  select * into b from public.purchase_bindings where token_hash=p_purchase_token_hash;
  if b.billing_principal_id is not null and not exists (
    select 1 from public.monetization_allowance_grants where purchase_token_hash=p_purchase_token_hash
  ) and not exists (
    select 1 from public.monetization_allowance_grants
     where billing_principal_id=b.billing_principal_id and granted_at>b.created_at
  ) then
   g:=public.apply_monetization_allowance_grant(b.billing_principal_id,p_purchase_token_hash,p_order_id,
    'purchase_activation',p_event_key,case when p_payload->>'source'='google_play_rtdn' then 4 else null end,300,p_expires_at);
   if coalesce((g->>'granted')::boolean,false) then
    select * into w from public.monetization_wallets where billing_principal_id=b.billing_principal_id;
    update public.monetization_entitlement_events set event_type='subscription_activated',
      metadata=metadata || jsonb_build_object('allowanceGrantCause','purchase_activation','allowanceOrderId',p_order_id)
      where event_key=p_event_key;
    r:=r||jsonb_build_object('eventType','subscription_activated','creditsGranted',300,
      'allowanceGrantReason',g->>'reason','remainingCredits',w.balance);
   end if;
  end if;
 end if;
 return r;
end;
$$;
revoke all on function public.reconcile_google_play_subscription(text,text,text,boolean,boolean,text,timestamptz,timestamptz,text,jsonb) from public,anon,authenticated;
grant execute on function public.reconcile_google_play_subscription(text,text,text,boolean,boolean,text,timestamptz,timestamptz,text,jsonb) to service_role;
