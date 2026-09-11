CREATE OR REPLACE FUNCTION public.reset_monetization_allowance(p_user_id uuid)
 RETURNS monetization_wallets
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_principal uuid; v_wallet public.monetization_wallets;
  v_status public.monetization_subscription_statuses; v_index integer;
  v_end timestamptz; v_amount integer; v_before integer;
begin
  v_principal := public.ensure_billing_principal(p_user_id);
  v_wallet := public.ensure_monetization_wallet_for_principal(v_principal);
  select * into v_status from public.monetization_subscription_statuses
    where billing_principal_id=v_principal for update;
  -- Complimentary review credit is a fixed allowance, never a paid renewal.
  -- This branch also runs before the period fast-path so revocation is immediate.
  if v_status.source='complimentary_review' then
    if v_status.status<>'review_access' or not v_status.is_active
      or v_status.expires_at is null or v_status.expires_at<=now() then
      v_before:=v_wallet.allowance_remaining;
      update public.monetization_wallets set allowance_remaining=0,
        period_credits=0,balance=bonus_balance,tier='free',funded_until=null,
        period_ends_at=least(period_ends_at,now()),
        updated_at=now() where billing_principal_id=v_principal returning * into v_wallet;
      update public.monetization_subscription_statuses set is_active=false,
        auto_renews=false,status=case when status='revoked' then 'revoked' else 'expired' end,
        updated_at=now() where billing_principal_id=v_principal;
      if v_before>0 then
        insert into public.monetization_credit_transactions(
          billing_principal_id,user_id,type,amount,balance_after,source,description,metadata)
        values(v_principal,p_user_id,'allowance_expired',-v_before,v_wallet.balance,
          'complimentary_review','Unused review allowance removed',
          jsonb_build_object('reviewKey',v_status.metadata->>'reviewKey'));
      end if;
    end if;
    return v_wallet;
  end if;
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
$function$
;

-- Explicit account-bound reviewer access; no Google purchase record is created.
-- The service role cannot read auth.users directly. Expose only this boolean,
-- not credentials or an expanded table grant, through a service-only helper.
create function public.is_confirmed_review_account(p_user_id uuid)
returns boolean language sql stable security definer set search_path='' as $identity$
  select exists(select 1 from auth.users where id=p_user_id
    and email_confirmed_at is not null and not coalesce(is_anonymous,false));
$identity$;
revoke all on function public.is_confirmed_review_account(uuid) from public,anon,authenticated;
grant execute on function public.is_confirmed_review_account(uuid) to service_role;

create function public.grant_complimentary_review_access(
  p_user_id uuid, p_review_key text, p_credits integer, p_expires_at timestamptz
) returns jsonb language plpgsql security invoker set search_path='' as $grant$
declare
  v_principal uuid; v_wallet public.monetization_wallets;
  v_status public.monetization_subscription_statuses;
  v_event public.monetization_entitlement_events;
  v_added integer;
begin
  if p_user_id is null or p_review_key is null
    or p_review_key !~ '^review:[a-z0-9-]{8,80}$'
    or p_credits is null or p_credits<20 or p_credits>1000
    or p_expires_at is null or p_expires_at<=now()
    or p_expires_at>now()+interval '31 days' then
    raise exception 'invalid bounded review grant';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:review:'||p_review_key,0));
  select * into v_event from public.monetization_entitlement_events
    where event_key=p_review_key;
  if found then
    if v_event.user_id is distinct from p_user_id then
      raise exception 'review grant ownership mismatch';
    end if;
    return jsonb_build_object('duplicate',true,'creditsGranted',0,
      'expiresAt',v_event.expires_at,'reviewKey',p_review_key);
  end if;
  if not public.is_confirmed_review_account(p_user_id) then
    raise exception 'confirmed nonanonymous reviewer required';
  end if;
  v_principal:=public.ensure_billing_principal(p_user_id);
  if exists(select 1 from public.purchase_bindings where billing_principal_id=v_principal)
    or exists(select 1 from public.credit_topup_purchases where billing_principal_id=v_principal) then
    raise exception 'review grant cannot replace purchase ownership';
  end if;
  select * into v_status from public.monetization_subscription_statuses
    where billing_principal_id=v_principal for update;
  if found and (v_status.source<>'complimentary_review' and v_status.plan_id<>'free'
    or v_status.is_active and v_status.expires_at>now()) then
    raise exception 'existing entitlement must not be replaced';
  end if;
  v_wallet:=public.reset_monetization_allowance(p_user_id);
  if v_wallet.bonus_balance<>0 or v_wallet.balance>p_credits
    or (coalesce(v_status.source,'')<>'complimentary_review' and v_wallet.lifetime_spent<>0) then
    raise exception 'review wallet must be isolated from customer balances';
  end if;
  v_added:=p_credits-v_wallet.balance;
  insert into public.monetization_subscription_statuses(
    billing_principal_id,user_id,plan_id,product_id,status,is_active,source,
    auto_renews,period_credits,started_at,expires_at,order_id,purchase_token_hash,
    metadata,updated_at,provider_event_time)
  values(v_principal,p_user_id,'premium_monthly','chronospark_premium_monthly',
    'review_access',true,'complimentary_review',false,0,now(),p_expires_at,null,null,
    jsonb_build_object('reviewKey',p_review_key,'reviewCreditLimit',p_credits),now(),now())
  on conflict(billing_principal_id) do update set
    user_id=excluded.user_id,plan_id=excluded.plan_id,product_id=excluded.product_id,
    status=excluded.status,is_active=true,source=excluded.source,auto_renews=false,
    period_credits=0,started_at=excluded.started_at,expires_at=excluded.expires_at,
    order_id=null,purchase_token_hash=null,metadata=excluded.metadata,
    updated_at=now(),provider_event_time=now();
  update public.monetization_wallets set balance=p_credits,allowance_remaining=p_credits,
    period_credits=0,lifetime_earned=lifetime_earned+v_added,tier='premium_monthly',
    period_ends_at=p_expires_at,funded_until=null,updated_at=now()
    where billing_principal_id=v_principal returning * into v_wallet;
  insert into public.monetization_credit_transactions(
    billing_principal_id,user_id,type,amount,balance_after,source,description,metadata)
  values(v_principal,p_user_id,'review_grant',v_added,v_wallet.balance,
    'complimentary_review','One-time review allowance',
    jsonb_build_object('reviewKey',p_review_key,'reviewCreditLimit',p_credits,'expiresAt',p_expires_at));
  insert into public.monetization_entitlement_events(
    billing_principal_id,user_id,event_type,event_key,plan_id,product_id,is_active,
    effective_at,expires_at,metadata)
  values(v_principal,p_user_id,'review_access_granted',p_review_key,
    'premium_monthly','chronospark_premium_monthly',true,now(),p_expires_at,
    jsonb_build_object('source','complimentary_review','creditsGranted',v_added,
      'reviewCreditLimit',p_credits,'autoRenews',false));
  return jsonb_build_object('granted',true,'duplicate',false,'reviewKey',p_review_key,
    'creditsGranted',v_added,'reviewCreditLimit',p_credits,'expiresAt',p_expires_at);
end;
$grant$;
revoke all on function public.grant_complimentary_review_access(uuid,text,integer,timestamptz)
  from public,anon,authenticated;
grant execute on function public.grant_complimentary_review_access(uuid,text,integer,timestamptz)
  to service_role;
