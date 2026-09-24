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
  retired_at timestamptz,
  pending_token_hash text unique check (pending_token_hash ~ '^[0-9a-f]{64}$'),
  pending_verified_at timestamptz,
  consumed_token_hash text unique check (consumed_token_hash ~ '^[0-9a-f]{64}$'),
  consumed_at timestamptz,
  check ((pending_token_hash is null) = (pending_verified_at is null)),
  check ((consumed_token_hash is null) = (consumed_at is null))
);
create index public_credit_checkout_admissions_principal_idx
  on public.public_credit_checkout_admissions (billing_principal_id, issued_at desc);
-- At most one unused admission per account/package can be stockpiled. Pending
-- tokens and completed purchases retain their own records independently.
create unique index public_credit_checkout_admissions_unused_idx
  on public.public_credit_checkout_admissions (billing_principal_id, product_id)
  where retired_at is null and pending_token_hash is null and consumed_token_hash is null;
create index public_credit_checkout_admissions_unused_expiry_idx
  on public.public_credit_checkout_admissions (issued_at)
  where retired_at is null and pending_token_hash is null and consumed_token_hash is null;
create index public_credit_checkout_admissions_retired_expiry_idx
  on public.public_credit_checkout_admissions (retired_at)
  where retired_at is not null and pending_token_hash is null
    and consumed_token_hash is null;
alter table public.public_credit_checkout_admissions enable row level security;
revoke all on public.public_credit_checkout_admissions from public, anon, authenticated;
grant select, insert, update, delete on public.public_credit_checkout_admissions to service_role;

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
  reason text not null check (reason in ('admission_expired_unbound', 'admission_missing')),
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

-- Service-only, aggregate health readback for the paid-order exception queue.
-- No token, order, account, or admission identifier leaves this function.
create function public.public_credit_checkout_resolution_health()
returns jsonb language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'awaiting', count(*) filter (where state = 'awaiting_resolution'),
    'awaitingOverOneHour', count(*) filter (
      where state = 'awaiting_resolution'
        and created_at <= now() - interval '1 hour'),
    'awaitingOverOneDay', count(*) filter (
      where state = 'awaiting_resolution'
        and created_at <= now() - interval '1 day'),
    'oldestAwaitingAt', min(created_at) filter (
      where state = 'awaiting_resolution'),
    'refunded', count(*) filter (where state = 'refunded'),
    'fulfilled', count(*) filter (where state = 'fulfilled')
  )
  from public.public_credit_checkout_resolutions;
$$;
revoke all on function public.public_credit_checkout_resolution_health()
  from public, anon, authenticated;
grant execute on function public.public_credit_checkout_resolution_health()
  to service_role;

-- A trusted Play void/refund is authoritative for the resolution queue too.
-- The same token lock used by grants and revocation makes the queue transition
-- atomic with the purchase tombstone, including voids before fulfillment.
create or replace function public.revoke_verified_credit_topup(
  p_token_hash text, p_product_id text, p_order_id text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_purchase public.credit_topup_purchases; v_wallet public.monetization_wallets;
  v_remove integer; v_credits integer;
begin
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid top-up token';
  end if;
  v_credits := case p_product_id when 'chronospark_credits_100' then 100
    when 'chronospark_credits_300' then 300 end;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('credit-topup:' || p_token_hash, 0));
  update public.public_credit_checkout_resolutions
    set state = 'refunded', last_verified_at = now()
    where token_hash = p_token_hash and state <> 'refunded';
  select * into v_purchase from public.credit_topup_purchases
    where token_hash = p_token_hash for update;
  if not found then
    insert into public.credit_topup_purchases
      (token_hash, product_id, order_id, credits, state, revoked_at)
      values (p_token_hash, p_product_id, p_order_id,
        coalesce(v_credits, 0), 'revoked', now());
    return jsonb_build_object('handled', true, 'revoked', true);
  end if;
  if v_purchase.state = 'revoked' then
    return jsonb_build_object('handled', true, 'duplicate', true);
  end if;
  select * into v_wallet from public.monetization_wallets
    where billing_principal_id = v_purchase.billing_principal_id for update;
  v_remove := least(v_wallet.bonus_balance, v_purchase.credits);
  update public.monetization_wallets set
    bonus_balance = bonus_balance - v_remove, balance = balance - v_remove,
    refunded_credit_debt = refunded_credit_debt + v_purchase.credits - v_remove,
    updated_at = now()
    where billing_principal_id = v_purchase.billing_principal_id
    returning * into v_wallet;
  update public.credit_topup_purchases set state = 'revoked', revoked_at = now()
    where token_hash = p_token_hash;
  insert into public.monetization_credit_transactions
    (billing_principal_id, user_id, type, amount, balance_after, source,
     description, metadata)
    values (v_purchase.billing_principal_id, v_wallet.user_id, 'adjustment',
      -v_remove, v_wallet.balance, 'google_play', 'Refunded top-up removed',
      jsonb_build_object('orderId', v_purchase.order_id,
        'alreadySpent', v_purchase.credits - v_remove));
  return jsonb_build_object('handled', true, 'revoked', true,
    'removed', v_remove);
end;
$$;
revoke all on function public.revoke_verified_credit_topup(text,text,text)
  from public, anon, authenticated;
grant execute on function public.revoke_verified_credit_topup(text,text,text)
  to service_role;

create function public.create_public_credit_checkout_admission(
  p_user_id uuid, p_product_id text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_principal uuid; v_id uuid;
begin
  if p_product_id is null or
    p_product_id not in ('chronospark_credits_100', 'chronospark_credits_300')
    or p_user_id is null then
    return jsonb_build_object('allowed', false, 'reason', 'invalid_product');
  end if;
  v_principal := public.ensure_billing_principal(p_user_id);
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'credit-admission:' || v_principal::text || ':' || p_product_id, 0));
  -- Repeated eligibility checks return the same live admission. Remove an
  -- expired unused one before issuing its replacement; a bound pending token
  -- is never removed here.
  update public.public_credit_checkout_admissions set retired_at = now()
    where billing_principal_id = v_principal and product_id = p_product_id
      and retired_at is null and pending_token_hash is null and consumed_token_hash is null
      and issued_at < now() - interval '30 minutes';
  select id into v_id from public.public_credit_checkout_admissions
    where billing_principal_id = v_principal and product_id = p_product_id
      and retired_at is null and pending_token_hash is null and consumed_token_hash is null
    for update;
  if found then
    return jsonb_build_object('allowed', true, 'admissionId', v_id::text);
  end if;
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

-- The server calls this only after Google confirms PURCHASED, account owner,
-- product, quantity, purchase type and order. An absent/malformed admission
-- cannot grant credits, but the verified paid order must remain discoverable.
create function public.queue_unadmitted_credit_topup(
  p_user_id uuid, p_token_hash text, p_product_id text, p_order_id text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  v_principal uuid;
  v_existing public.credit_topup_purchases;
  v_resolution public.public_credit_checkout_resolutions;
begin
  if p_user_id is null or p_token_hash is null or
    p_token_hash !~ '^[0-9a-f]{64}$' or
    p_product_id not in ('chronospark_credits_100', 'chronospark_credits_300') or
    nullif(btrim(p_order_id), '') is null or length(p_order_id) > 1024 then
    return jsonb_build_object('resolutionQueued', false, 'reason', 'invalid_proof');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('credit-topup:' || p_token_hash, 0));
  v_principal := public.ensure_billing_principal(p_user_id);
  select * into v_existing from public.credit_topup_purchases
    where token_hash = p_token_hash for update;
  if found then
    return jsonb_build_object('resolutionQueued', false,
      'reason', 'already_processed');
  end if;
  select * into v_resolution from public.public_credit_checkout_resolutions
    where token_hash = p_token_hash for update;
  if found then
    if v_resolution.billing_principal_id is distinct from v_principal or
      v_resolution.product_id <> p_product_id or
      v_resolution.order_id <> p_order_id then
      return jsonb_build_object('resolutionQueued', false,
        'reason', 'resolution_proof_mismatch');
    end if;
    update public.public_credit_checkout_resolutions
      set last_verified_at = now() where token_hash = p_token_hash;
    return jsonb_build_object('resolutionQueued', true, 'duplicate', true);
  end if;
  insert into public.public_credit_checkout_resolutions
    (token_hash, billing_principal_id, product_id, order_id, reason)
    values (p_token_hash, v_principal, p_product_id, p_order_id,
      'admission_missing');
  return jsonb_build_object('resolutionQueued', true, 'duplicate', false);
end;
$$;
revoke all on function public.queue_unadmitted_credit_topup(uuid,text,text,text)
  from public, anon, authenticated;
grant execute on function public.queue_unadmitted_credit_topup(uuid,text,text,text)
  to service_role;

-- The existing four-argument grant remains for the currently deployed
-- license-test verifier. The new verifier exclusively calls this version;
-- admission and wallet grant are atomic under the receipt token lock.
create function public.grant_verified_credit_topup_v2(
  p_user_id uuid, p_token_hash text, p_product_id text, p_order_id text,
  p_admission_exempt boolean, p_admission_id text, p_purchase_time_ms bigint
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
    or p_admission_exempt is null then
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
  if not p_admission_exempt then
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
    if not found then
      if exists (select 1 from public.public_credit_checkout_admissions
        where id = p_admission_id::uuid) then
        return jsonb_build_object('granted', false, 'reason', 'admission_invalid');
      end if;
      -- A verified paid order may arrive after an unused admission was
      -- purged. Preserve the customer claim rather than silently lose it.
      insert into public.public_credit_checkout_resolutions
        (token_hash, billing_principal_id, product_id, order_id, reason)
        values (p_token_hash, v_principal, p_product_id, p_order_id,
          'admission_missing');
      return jsonb_build_object('granted', false,
        'reason', 'customer_resolution_required', 'resolutionQueued', true);
    end if;
    if v_admission.consumed_token_hash is not null
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

-- Retire unused admissions when their checkout window closes. Keep rows
-- linked to verified paid-order resolutions and all pending/consumed rows;
-- purging only unbound rows cannot cancel an in-flight pending payment.
create function public.purge_expired_public_credit_checkout_admissions()
returns integer language plpgsql security invoker set search_path = '' as $$
declare v_count integer;
begin
  update public.public_credit_checkout_admissions
    set retired_at = now()
    where retired_at is null and pending_token_hash is null
      and consumed_token_hash is null
      and issued_at < now() - interval '30 minutes';
  with expired as (
    select a.id from public.public_credit_checkout_admissions a
    where a.retired_at < now() - interval '24 hours'
      and a.pending_token_hash is null and a.consumed_token_hash is null
      and not exists (select 1 from public.public_credit_checkout_resolutions r
        where r.admission_id = a.id)
    order by a.retired_at limit 1000
  )
  delete from public.public_credit_checkout_admissions a
    using expired where a.id = expired.id;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function public.purge_expired_public_credit_checkout_admissions()
  from public, anon, authenticated;
grant execute on function public.purge_expired_public_credit_checkout_admissions()
  to service_role;

create extension if not exists pg_cron;
do $$
declare v_job_id bigint;
begin
  for v_job_id in select jobid from cron.job
    where jobname = 'chronospark-purge-public-credit-admissions'
  loop
    perform cron.unschedule(v_job_id);
  end loop;
  perform cron.schedule(
    'chronospark-purge-public-credit-admissions',
    '*/15 * * * *',
    'select public.purge_expired_public_credit_checkout_admissions();');
exception when others then
  raise exception 'failed to configure public credit admission cleanup: %', sqlerrm;
end;
$$;
