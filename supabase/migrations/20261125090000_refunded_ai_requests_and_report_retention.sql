-- 1. A refunded AI request no longer counts toward the 200-credit daily budget.
--    The person was refunded, so the credits they were charged for it are not
--    spent. Only reserve_ai_usage_for_principal changes, and only its two
--    rolling 24-hour credit sums (per account and global): the state filter
--    drops 'refunded'. The body is otherwise copied unchanged from
--    20260920023350_preserve_ai_denial_reason.sql. CREATE OR REPLACE keeps the
--    existing grants and the wrapper that calls it.
--
--    A refunded request still cost a model call, so this does NOT open free
--    calls. The provider-cost accounting that bounds real spending is left as
--    it is and still counts 'refunded' rows at their known provider cost:
--      * reserve_ai_repair_budget_for_principal: 600000 microUSD per account and
--        60000000 global per rolling 24 hours (accounted cost, reserved cost if
--        the usage is unknown), checked before every provider call;
--      * the lifetime check inside reserve_ai_usage_for_principal below
--        (v_accounted) that compares all provider cost ever accounted against
--        what the account earned;
--      * the per-minute rate limits in ai-proxy (20 per account, 60 per
--        address). Refunds before any provider call carry zero cost.
--
create or replace function public.reserve_ai_usage_for_principal(
  p_billing_principal_id uuid,
  p_request_key text,
  p_credit_amount integer,
  p_prompt_hash text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_existing public.ai_usage_requests;
  v_wallet public.monetization_wallets;
  v_principal public.billing_principals;
  v_bonus_used integer;
  v_allowance_used integer;
  v_principal_daily integer;
  v_global_daily integer;
  v_accounted bigint;
begin
  if p_billing_principal_id is null
    or p_request_key is null
    or p_request_key !~ '^[A-Za-z0-9._:=+-]{8,200}$'
    or p_credit_amount is null
    or p_credit_amount not between 1 and 100
    or p_prompt_hash is null
    or p_prompt_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid AI reservation request';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'chronospark:ai:' || p_billing_principal_id::text || ':' || p_request_key,
      0
    )
  );
  select * into v_principal from public.billing_principals
  where billing_principal_id = p_billing_principal_id
    and retired_at is null
    and current_user_id is not null
  for update;
  if not found then raise exception 'billing principal unavailable'; end if;

  select * into v_existing from public.ai_usage_requests
  where billing_principal_id = p_billing_principal_id
    and request_key = p_request_key
  for update;
  if found then
    select * into v_wallet from public.monetization_wallets
    where billing_principal_id = p_billing_principal_id;
    if v_existing.prompt_hash <> p_prompt_hash
      or v_existing.credit_amount <> p_credit_amount then
      return jsonb_build_object(
        'allowed', false,
        'state', v_existing.state,
        'duplicate', false,
        'reason', 'idempotency_mismatch',
        'balance', coalesce(v_wallet.balance, 0)
      );
    end if;
    return jsonb_build_object(
      'allowed', v_existing.state in ('reserved', 'completed'),
      'state', v_existing.state,
      'duplicate', true,
      'creditAmount', v_existing.credit_amount,
      'balance', coalesce(v_wallet.balance, 0),
      'responsePayload', v_existing.response_payload,
      'reason', v_existing.failure_code
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:ai-daily-budget', 0)
  );
  select coalesce(sum(credit_amount), 0)::integer into v_principal_daily
  from public.ai_usage_requests
  where billing_principal_id = p_billing_principal_id
    and created_at >= now() - interval '24 hours'
    and state in ('reserved', 'completed');
  select coalesce(sum(credit_amount), 0)::integer into v_global_daily
  from public.ai_usage_requests
  where created_at >= now() - interval '24 hours'
    and state in ('reserved', 'completed');
  if v_principal_daily + p_credit_amount > 200
    or v_global_daily + p_credit_amount > 20000 then
    insert into public.ai_usage_requests (
      billing_principal_id, user_id, request_key, state, credit_amount,
      prompt_hash, failure_code, settled_at
    ) values (
      p_billing_principal_id, v_principal.current_user_id, p_request_key,
      'denied', p_credit_amount, p_prompt_hash, 'daily_budget_exceeded', now()
    );
    return jsonb_build_object(
      'allowed', false, 'state', 'denied',
      'reason', 'daily_budget_exceeded'
    );
  end if;

  v_wallet := public.ensure_monetization_wallet_for_principal(
    p_billing_principal_id
  );
  select * into v_wallet from public.monetization_wallets
  where billing_principal_id = p_billing_principal_id for update;
  if v_wallet.period_ends_at is not null
    and v_wallet.period_ends_at <= now() then
    perform public.reset_monetization_allowance(v_principal.current_user_id);
    select * into v_wallet from public.monetization_wallets
    where billing_principal_id = p_billing_principal_id for update;
  end if;

  select coalesce(sum(coalesce(accounted_provider_cost_microusd,
    reserved_provider_cost_microusd,credit_amount::bigint*3000)),0) into v_accounted
  from public.ai_usage_requests where billing_principal_id=p_billing_principal_id
    and state in ('reserved','completed','refunded');
  if v_accounted+p_credit_amount::bigint*3000 > v_wallet.lifetime_earned::bigint*3000 then
    return jsonb_build_object('allowed',false,'reason','provider_cost_budget_exceeded','balance',v_wallet.balance);
  end if;
  if v_wallet.refunded_credit_debt > 0 then
    return jsonb_build_object('allowed',false,'reason','refunded_credits_outstanding','balance',v_wallet.balance);
  end if;
  if v_wallet.balance < p_credit_amount then
    insert into public.ai_usage_requests (
      billing_principal_id, user_id, request_key, state, credit_amount,
      prompt_hash, failure_code, settled_at
    ) values (
      p_billing_principal_id, v_principal.current_user_id, p_request_key,
      'denied', p_credit_amount, p_prompt_hash, 'insufficient_credits', now()
    );
    return jsonb_build_object(
      'allowed', false, 'state', 'denied',
      'reason', 'insufficient_credits', 'balance', v_wallet.balance
    );
  end if;

  v_allowance_used := least(v_wallet.allowance_remaining, p_credit_amount);
  v_bonus_used := p_credit_amount - v_allowance_used;
  update public.monetization_wallets
  set bonus_balance = bonus_balance - v_bonus_used,
    allowance_remaining = greatest(allowance_remaining - v_allowance_used, 0),
    balance = balance - p_credit_amount,
    lifetime_spent = lifetime_spent + p_credit_amount,
    updated_at = now()
  where billing_principal_id = p_billing_principal_id
  returning * into v_wallet;
  insert into public.ai_usage_requests (
    billing_principal_id, user_id, request_key, state, credit_amount,
    bonus_used, allowance_used, prompt_hash, funding_period_ends_at, reserved_provider_cost_microusd, model_key
  ) values (
    p_billing_principal_id, v_principal.current_user_id, p_request_key,
    'reserved', p_credit_amount, v_bonus_used, v_allowance_used, p_prompt_hash, v_wallet.period_ends_at, p_credit_amount::bigint*3000, 'claude-sonnet-4-6'
  );
  insert into public.monetization_credit_transactions (
    billing_principal_id, user_id, type, amount, balance_after,
    source, description, metadata
  ) values (
    p_billing_principal_id, v_principal.current_user_id, 'spend',
    -p_credit_amount, v_wallet.balance, 'ai_proxy', 'AI request reserved',
    jsonb_build_object('request_key', p_request_key)
  );
  return jsonb_build_object(
    'allowed', true, 'state', 'reserved', 'duplicate', false,
    'creditAmount', p_credit_amount, 'balance', v_wallet.balance
  );
end;
$$;

-- 2. Retention for stored AI content reports. The reported reply text (up to
--    4000 characters) stays linked to the account only for a fixed period.
--    purge_expired_ai_content_reports(retention) replaces the text of every
--    report older than the period with a fixed placeholder. reason, source,
--    status, created_at and user_id are kept (the account link still cascades
--    on account deletion), so counts of reports by reason and surface remain.
--    It is idempotent: a scrubbed row is not touched again. Nothing is deleted.
--
--    Period: 180 days. The repository documents no other period for these
--    reports (the 24-hour period elsewhere is for cached AI replies).
--
--    When it runs: NOT at migration time. A daily pg_cron job (03:17 UTC) calls
--    it. ai_content_reports exists since 2026-08-17, so no existing row is
--    older than 180 days before 2027-02-13: the first run that can change any
--    data is on or after that date. The database owner can also run it by hand:
--    select public.purge_expired_ai_content_reports(interval '180 days');
create or replace function public.purge_expired_ai_content_reports(
  p_retention interval default interval '180 days'
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
  v_count integer;
begin
  if p_retention is null or p_retention < interval '30 days' then
    raise exception 'AI report retention must be at least 30 days';
  end if;
  update public.ai_content_reports
  set content = '[removed after retention period]'
  where created_at < now() - p_retention
    and content <> '[removed after retention period]';
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

-- No client or API role can run it. service_role has only INSERT on the table
-- (20260830050000), so a grant to it would be unusable anyway. The cron job
-- and a manual run by the database owner (postgres) are the only callers.
revoke all on function public.purge_expired_ai_content_reports(interval)
  from public, anon, authenticated, service_role;

create extension if not exists pg_cron;
do $cron$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'axiomara-purge-ai-content-reports';
  perform cron.schedule(
    'axiomara-purge-ai-content-reports',
    '17 3 * * *',
    'select public.purge_expired_ai_content_reports(interval ''180 days'');'
  );
end;
$cron$;
