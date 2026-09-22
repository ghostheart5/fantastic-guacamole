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

commit;
