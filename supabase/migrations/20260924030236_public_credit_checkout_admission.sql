-- A public credit checkout is admitted by the authenticated server before
-- Google Play opens. Play echoes the opaque ID in the signed purchase proof.
-- The admission is one-use and survives a rollout closure or a delayed
-- payment. Google may report a pending payment as purchased well after the
-- checkout began; expiry based on purchase completion would strand a charge.
create table public.public_credit_checkout_admissions (
  id uuid primary key default gen_random_uuid(),
  billing_principal_id uuid not null references public.billing_principals(billing_principal_id),
  product_id text not null check (product_id in ('chronospark_credits_100', 'chronospark_credits_300')),
  issued_at timestamptz not null default now(),
  pending_token_hash text unique check (pending_token_hash ~ '^[0-9a-f]{64}$'),
  pending_verified_at timestamptz,
  consumed_token_hash text unique check (consumed_token_hash ~ '^[0-9a-f]{64}$'),
  consumed_at timestamptz,
  check ((pending_token_hash is null) = (pending_verified_at is null)),
  check ((consumed_token_hash is null) = (consumed_at is null))
);
create index public_credit_checkout_admissions_principal_idx
  on public.public_credit_checkout_admissions (billing_principal_id, issued_at desc);
alter table public.public_credit_checkout_admissions enable row level security;
revoke all on public.public_credit_checkout_admissions from public, anon, authenticated;
grant select, insert, update on public.public_credit_checkout_admissions to service_role;

-- A Google-verified completed payment which cannot safely receive credits is
-- retained for customer resolution. Do not turn a rejected paid receipt into
-- an endless RTDN retry or silently discard its order ID. This table does not
-- itself authorize a refund or a credit grant.
create table public.public_credit_checkout_resolutions (
  token_hash text primary key check (token_hash ~ '^[0-9a-f]{64}$'),
  billing_principal_id uuid not null references public.billing_principals(billing_principal_id),
  product_id text not null check (product_id in ('chronospark_credits_100', 'chronospark_credits_300')),
  order_id text not null,
  admission_id uuid references public.public_credit_checkout_admissions(id),
  reason text not null check (reason = 'admission_expired_unbound'),
  state text not null default 'awaiting_resolution'
    check (state in ('awaiting_resolution', 'refunded', 'fulfilled')),
  created_at timestamptz not null default now(),
  last_verified_at timestamptz not null default now()
);
create index public_credit_checkout_resolutions_state_idx
  on public.public_credit_checkout_resolutions (state, created_at);
alter table public.public_credit_checkout_resolutions enable row level security;
revoke all on public.public_credit_checkout_resolutions from public, anon, authenticated;
grant select, insert, update on public.public_credit_checkout_resolutions to service_role;

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

-- Called only after the receipt verifier confirms PENDING with Google and
-- checks the Play-echoed account, profile/admission and product identifiers.
-- A pending purchase is bound, never granted, consumed or acknowledged here.
create function public.register_verified_pending_credit_topup(
  p_user_id uuid, p_token_hash text, p_product_id text, p_admission_id text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_principal uuid; v_admission public.public_credit_checkout_admissions;
begin
  if p_user_id is null or p_token_hash is null or
    p_token_hash !~ '^[0-9a-f]{64}$' or p_admission_id is null or
    p_admission_id !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or
    p_product_id not in ('chronospark_credits_100', 'chronospark_credits_300') then
    return jsonb_build_object('registered', false, 'reason', 'invalid_pending_proof');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('credit-topup:' || p_token_hash, 0));
  v_principal := public.ensure_billing_principal(p_user_id);
  select * into v_admission from public.public_credit_checkout_admissions
    where id = p_admission_id::uuid and billing_principal_id = v_principal
      and product_id = p_product_id for update;
  if not found or v_admission.consumed_token_hash is not null then
    return jsonb_build_object('registered', false, 'reason', 'admission_invalid');
  end if;
  if v_admission.pending_token_hash = p_token_hash then
    return jsonb_build_object('registered', true, 'duplicate', true);
  end if;
  if v_admission.pending_token_hash is not null or
    v_admission.issued_at > now() + interval '1 minute' or
    now() > v_admission.issued_at + interval '30 minutes' or
    exists (select 1 from public.public_credit_checkout_admissions
      where pending_token_hash = p_token_hash and id <> v_admission.id) then
    return jsonb_build_object('registered', false, 'reason', 'admission_expired_or_bound');
  end if;
  update public.public_credit_checkout_admissions
    set pending_token_hash = p_token_hash, pending_verified_at = now()
    where id = v_admission.id;
  return jsonb_build_object('registered', true, 'duplicate', false);
end;
$$;
revoke all on function public.register_verified_pending_credit_topup(uuid,text,text,text)
  from public, anon, authenticated;
grant execute on function public.register_verified_pending_credit_topup(uuid,text,text,text)
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
  v_resolution public.public_credit_checkout_resolutions;
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
  select * into v_resolution from public.public_credit_checkout_resolutions
    where token_hash = p_token_hash for update;
  if found then
    if v_resolution.billing_principal_id is distinct from v_principal or
      v_resolution.product_id <> p_product_id or
      v_resolution.order_id <> p_order_id then
      return jsonb_build_object('granted', false, 'reason', 'resolution_proof_mismatch');
    end if;
    update public.public_credit_checkout_resolutions
      set last_verified_at = now() where token_hash = p_token_hash;
    return jsonb_build_object('granted', false,
      'reason', 'customer_resolution_required', 'resolutionQueued', true);
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
      or v_purchase_at < v_admission.issued_at - interval '1 minute' then
      return jsonb_build_object('granted', false, 'reason', 'admission_invalid');
    end if;
    if v_admission.pending_token_hash is not null and
      v_admission.pending_token_hash <> p_token_hash then
      return jsonb_build_object('granted', false, 'reason', 'admission_invalid');
    end if;
    if v_purchase_at > v_admission.issued_at + interval '30 minutes' and
      (v_admission.pending_token_hash is distinct from p_token_hash or
       v_admission.pending_verified_at > v_admission.issued_at + interval '30 minutes') then
      insert into public.public_credit_checkout_resolutions
        (token_hash, billing_principal_id, product_id, order_id, admission_id,
         reason)
        values (p_token_hash, v_principal, p_product_id, p_order_id,
          v_admission.id, 'admission_expired_unbound');
      return jsonb_build_object('granted', false,
        'reason', 'customer_resolution_required', 'resolutionQueued', true);
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
