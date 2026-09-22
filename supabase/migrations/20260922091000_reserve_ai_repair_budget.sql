begin;

create or replace function public.reserve_ai_repair_budget_for_principal(
  p_billing_principal_id uuid,
  p_request_key text,
  p_required_provider_cost_microusd bigint
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_usage public.ai_usage_requests;
  v_wallet public.monetization_wallets;
  v_principal public.billing_principals;
  v_accounted bigint;
  v_current_reserved bigint;
  v_delta bigint;
begin
  if p_billing_principal_id is null
    or p_request_key is null
    or p_request_key !~ '^[A-Za-z0-9._:=+-]{8,200}$'
    or p_required_provider_cost_microusd is null
    or p_required_provider_cost_microusd not between 1 and 1000000 then
    raise exception 'invalid AI repair budget request';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'chronospark:ai:' || p_billing_principal_id::text || ':' || p_request_key,
      0
    )
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:ai-daily-budget', 0)
  );

  select * into v_usage from public.ai_usage_requests
  where billing_principal_id = p_billing_principal_id
    and request_key = p_request_key
  for update;
  if not found then
    raise exception 'AI reservation not found';
  end if;
  if v_usage.state <> 'reserved' then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'request_' || v_usage.state
    );
  end if;

  select * into v_principal from public.billing_principals
  where billing_principal_id = p_billing_principal_id
    and retired_at is null
    and current_user_id is not null;
  if not found then
    return jsonb_build_object('allowed', false, 'reason', 'account_detached');
  end if;
  select * into v_wallet from public.monetization_wallets
  where billing_principal_id = p_billing_principal_id;
  if not found then
    raise exception 'billing wallet not found';
  end if;

  v_current_reserved := coalesce(
    v_usage.reserved_provider_cost_microusd,
    v_usage.credit_amount::bigint * 3000
  );
  if p_required_provider_cost_microusd <= v_current_reserved then
    return jsonb_build_object(
      'allowed', true,
      'reservedProviderCostMicrousd', v_current_reserved,
      'duplicate', true
    );
  end if;
  v_delta := p_required_provider_cost_microusd - v_current_reserved;

  select coalesce(sum(coalesce(
    accounted_provider_cost_microusd,
    reserved_provider_cost_microusd,
    credit_amount::bigint * 3000
  )), 0) into v_accounted
  from public.ai_usage_requests
  where billing_principal_id = p_billing_principal_id
    and state in ('reserved', 'completed', 'refunded');

  if v_accounted + v_delta > v_wallet.lifetime_earned::bigint * 3000 then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'provider_cost_budget_exceeded'
    );
  end if;

  update public.ai_usage_requests
  set reserved_provider_cost_microusd = p_required_provider_cost_microusd
  where id = v_usage.id;
  return jsonb_build_object(
    'allowed', true,
    'reservedProviderCostMicrousd', p_required_provider_cost_microusd,
    'duplicate', false
  );
end;
$$;

create or replace function public.reserve_ai_repair_budget(
  p_user_id uuid,
  p_request_key text,
  p_required_provider_cost_microusd bigint
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
begin
  return public.reserve_ai_repair_budget_for_principal(
    public.ensure_billing_principal(p_user_id),
    p_request_key,
    p_required_provider_cost_microusd
  );
end;
$$;

revoke all on function public.reserve_ai_repair_budget_for_principal(
  uuid, text, bigint
) from public, anon, authenticated, service_role;
revoke all on function public.reserve_ai_repair_budget(
  uuid, text, bigint
) from public, anon, authenticated, service_role;
grant execute on function public.reserve_ai_repair_budget_for_principal(
  uuid, text, bigint
) to service_role;
grant execute on function public.reserve_ai_repair_budget(
  uuid, text, bigint
) to service_role;

-- A handled provider failure supplies authoritative usage. Account that actual
-- work rather than a larger repair-call reservation that was never consumed.
-- Unhandled and stale failures omit usage and conservatively retain the full
-- reserved provider cost.
create or replace function public.settle_ai_usage_for_principal(
  p_billing_principal_id uuid,
  p_request_key text,
  p_succeeded boolean,
  p_input_tokens integer default null,
  p_output_tokens integer default null,
  p_provider_request_id text default null,
  p_failure_code text default null,
  p_response_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_usage public.ai_usage_requests;
  v_wallet public.monetization_wallets;
  v_principal public.billing_principals;
  v_effective_success boolean;
  v_failure_code text;
  v_allowance_refund integer;
  v_bonus_refund integer;
  v_debt_reversed integer;
  v_refund integer;
  v_actual_provider_cost_microusd bigint;
begin
  select * into v_usage from public.ai_usage_requests
  where billing_principal_id = p_billing_principal_id
    and request_key = p_request_key
  for update;
  if not found then raise exception 'AI reservation not found'; end if;
  if v_usage.state <> 'reserved' then
    return jsonb_build_object('state', v_usage.state, 'duplicate', true);
  end if;

  select * into v_principal from public.billing_principals
  where billing_principal_id = p_billing_principal_id;
  if not found then raise exception 'billing principal not found'; end if;
  v_effective_success := p_succeeded
    and v_principal.current_user_id is not null
    and v_principal.retired_at is null;
  v_actual_provider_cost_microusd :=
    greatest(coalesce(p_input_tokens, 0), 0)::bigint * 3
    + greatest(coalesce(p_output_tokens, 0), 0)::bigint * 15;
  if v_effective_success then
    update public.ai_usage_requests set state = 'completed',
      input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
      output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
      provider_request_id = left(p_provider_request_id, 200),
      response_payload = coalesce(p_response_payload, '{}'::jsonb),
      accounted_provider_cost_microusd = v_actual_provider_cost_microusd,
      settled_at = now()
    where id = v_usage.id;
    return jsonb_build_object('state', 'completed', 'refunded', false);
  end if;

  select * into v_wallet from public.monetization_wallets
  where billing_principal_id = p_billing_principal_id for update;
  if not found then raise exception 'billing wallet not found'; end if;
  v_allowance_refund := case
    when v_wallet.period_ends_at is not distinct from v_usage.funding_period_ends_at
      then v_usage.allowance_used
    else 0
  end;
  v_debt_reversed := least(v_wallet.refunded_credit_debt, v_usage.bonus_used);
  v_bonus_refund := v_usage.bonus_used - v_debt_reversed;
  v_refund := v_bonus_refund + v_allowance_refund;
  update public.monetization_wallets set
    bonus_balance = bonus_balance + v_bonus_refund,
    refunded_credit_debt = refunded_credit_debt - v_debt_reversed,
    allowance_remaining = allowance_remaining + v_allowance_refund,
    balance = balance + v_refund,
    lifetime_spent = greatest(lifetime_spent - v_usage.credit_amount, 0),
    updated_at = now()
  where billing_principal_id = p_billing_principal_id
  returning * into v_wallet;
  v_failure_code := case
    when p_succeeded then 'account_detached'
    else coalesce(p_failure_code, 'provider_failure')
  end;
  update public.ai_usage_requests set state = 'refunded',
    input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
    output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
    provider_request_id = null,
    response_payload = '{}'::jsonb,
    failure_code = left(v_failure_code, 100),
    accounted_provider_cost_microusd = case
      when p_input_tokens is not null or p_output_tokens is not null
        then v_actual_provider_cost_microusd
      else coalesce(
        v_usage.reserved_provider_cost_microusd,
        v_usage.credit_amount::bigint * 3000
      )
    end,
    settled_at = now()
  where id = v_usage.id;
  if v_principal.retired_at is null then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description, metadata
    ) values (
      p_billing_principal_id, v_principal.current_user_id, 'refund',
      v_refund, v_wallet.balance, 'ai_proxy',
      'AI request reservation refunded',
      jsonb_build_object(
        'request_key', p_request_key, 'failure_code', v_failure_code
      )
    );
  end if;
  return jsonb_build_object(
    'state', 'refunded', 'refunded', true, 'balance', v_wallet.balance
  );
end;
$$;

commit;
