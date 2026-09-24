-- A public credit checkout is admitted by the authenticated server before
-- Google Play opens. Play echoes the opaque ID in the signed purchase proof.
-- The admission is one-use and survives a rollout closure for RTDN recovery.
create table public.public_credit_checkout_admissions (
  id uuid primary key default gen_random_uuid(),
  billing_principal_id uuid not null references public.billing_principals(billing_principal_id),
  product_id text not null check (product_id in ('chronospark_credits_100', 'chronospark_credits_300')),
  issued_at timestamptz not null default now(),
  purchase_deadline timestamptz not null default (now() + interval '30 minutes'),
  consumed_token_hash text unique check (consumed_token_hash ~ '^[0-9a-f]{64}$'),
  consumed_at timestamptz,
  check ((consumed_token_hash is null) = (consumed_at is null))
);
create index public_credit_checkout_admissions_principal_idx
  on public.public_credit_checkout_admissions (billing_principal_id, issued_at desc);
alter table public.public_credit_checkout_admissions enable row level security;
revoke all on public.public_credit_checkout_admissions from public, anon, authenticated;
grant select, insert, update on public.public_credit_checkout_admissions to service_role;

create function public.create_public_credit_checkout_admission(
  p_user_id uuid, p_product_id text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_principal uuid; v_id uuid;
begin
  if p_product_id not in ('chronospark_credits_100', 'chronospark_credits_300')
    or p_user_id is null then
    return jsonb_build_object('allowed', false, 'reason', 'invalid_product');
  end if;
  v_principal := public.ensure_billing_principal(p_user_id);
  insert into public.public_credit_checkout_admissions (billing_principal_id, product_id)
    values (v_principal, p_product_id) returning id into v_id;
  return jsonb_build_object('allowed', true, 'admissionId', v_id::text);
end;
$$;
revoke all on function public.create_public_credit_checkout_admission(uuid,text)
  from public, anon, authenticated;
grant execute on function public.create_public_credit_checkout_admission(uuid,text)
  to service_role;

-- The existing four-argument grant remains for the currently deployed
-- license-test verifier. The new verifier exclusively calls this version;
-- admission and wallet grant are atomic under the receipt token lock.
create function public.grant_verified_credit_topup_v2(
  p_user_id uuid, p_token_hash text, p_product_id text, p_order_id text,
  p_is_license_test boolean, p_admission_id text, p_purchase_time_ms bigint
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  v_principal uuid; v_existing public.credit_topup_purchases;
  v_admission public.public_credit_checkout_admissions;
  v_wallet public.monetization_wallets; v_credits integer; v_debt_paid integer;
  v_purchase_at timestamptz;
begin
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$'
    or nullif(btrim(p_order_id), '') is null or length(p_order_id) > 1024
    or p_is_license_test is null then
    raise exception 'invalid top-up proof';
  end if;
  select credits into v_credits from public.monetization_credit_packages
    where product_id = p_product_id and is_active;
  if v_credits not in (100, 300) or v_credits is null then
    raise exception 'unsupported top-up';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('credit-topup:' || p_token_hash, 0));
  v_principal := public.ensure_billing_principal(p_user_id);
  select * into v_existing from public.credit_topup_purchases
    where token_hash = p_token_hash for update;
  if found then
    if v_existing.state = 'revoked' then
      return jsonb_build_object('granted', false, 'reason', 'revoked');
    end if;
    if v_existing.billing_principal_id is distinct from v_principal
      or v_existing.product_id <> p_product_id then
      return jsonb_build_object('granted', false, 'reason', 'ownership_mismatch');
    end if;
    return jsonb_build_object('granted', true, 'duplicate', true,
      'credits', v_existing.credits, 'reason', v_existing.state);
  end if;
  if not p_is_license_test then
    if p_admission_id is null or p_admission_id !~
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or p_purchase_time_ms is null or p_purchase_time_ms < 1600000000000
      or p_purchase_time_ms > 4102444800000 then
      return jsonb_build_object('granted', false, 'reason', 'admission_missing');
    end if;
    v_purchase_at := to_timestamp(p_purchase_time_ms / 1000.0);
    select * into v_admission from public.public_credit_checkout_admissions
      where id = p_admission_id::uuid and billing_principal_id = v_principal
        and product_id = p_product_id for update;
    if not found or v_admission.consumed_token_hash is not null
      or v_purchase_at < v_admission.issued_at - interval '1 minute'
      or v_purchase_at > v_admission.purchase_deadline then
      return jsonb_build_object('granted', false, 'reason', 'admission_invalid');
    end if;
    update public.public_credit_checkout_admissions
      set consumed_token_hash = p_token_hash, consumed_at = now()
      where id = v_admission.id;
  end if;
  v_wallet := public.ensure_monetization_wallet_for_principal(v_principal);
  v_debt_paid := least(v_wallet.refunded_credit_debt, v_credits);
  insert into public.credit_topup_purchases
    (token_hash, billing_principal_id, product_id, order_id, credits, state)
    values (p_token_hash, v_principal, p_product_id, p_order_id, v_credits, 'granted');
  update public.monetization_wallets set
    bonus_balance = bonus_balance + v_credits - v_debt_paid,
    balance = balance + v_credits - v_debt_paid,
    refunded_credit_debt = refunded_credit_debt - v_debt_paid,
    lifetime_earned = lifetime_earned + v_credits, updated_at = now()
    where billing_principal_id = v_principal returning * into v_wallet;
  insert into public.monetization_credit_transactions
    (billing_principal_id, user_id, type, amount, balance_after, source, description, metadata)
    values (v_principal, p_user_id, 'purchase', v_credits - v_debt_paid,
      v_wallet.balance, 'google_play', 'Purchased non-expiring AI credits',
      jsonb_build_object('orderId', p_order_id, 'refundedCreditsRepaid', v_debt_paid));
  return jsonb_build_object('granted', true, 'duplicate', false,
    'credits', v_credits, 'balance', v_wallet.balance);
end;
$$;
revoke all on function public.grant_verified_credit_topup_v2(uuid,text,text,text,boolean,text,bigint)
  from public, anon, authenticated;
grant execute on function public.grant_verified_credit_topup_v2(uuid,text,text,text,boolean,text,bigint)
  to service_role;
