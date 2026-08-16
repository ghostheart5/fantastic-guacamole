-- Recovered losslessly from GhostHeart5 production migration history.
-- Project: qpwhuckyirnqtmvhpede | Version: 20260816040848 | Name: edge_function_advanced_hardening
-- Production already records this version as applied. Do not reapply it manually.

-- Edge Function hardening: request identity, bounded account deletion,
-- response retention, and atomic Google Play event state transitions.

alter table public.ai_usage_requests
  add column if not exists contract_version text not null default 'ai-proxy-v2',
  add column if not exists response_expires_at timestamptz;

create index if not exists ai_usage_requests_response_expiry_idx
  on public.ai_usage_requests (response_expires_at)
  where response_expires_at is not null;

create or replace function public.reserve_ai_usage_v2(
  p_user_id uuid,
  p_request_key text,
  p_credit_amount integer,
  p_request_fingerprint text,
  p_contract_version text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_existing public.ai_usage_requests;
  v_result jsonb;
begin
  if p_user_id is null
    or p_request_key !~ '^[A-Za-z0-9._:-]{8,128}$'
    or p_request_fingerprint !~ '^[0-9a-f]{64}$'
    or p_contract_version !~ '^[A-Za-z0-9._:-]{3,64}$' then
    raise exception 'invalid AI reservation request';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'chronospark:ai-request:' || p_user_id::text || ':' || p_request_key,
      0
    )
  );

  select * into v_existing
  from public.ai_usage_requests
  where user_id = p_user_id and request_key = p_request_key
  for update;

  if found and (
    v_existing.prompt_hash <> p_request_fingerprint
    or v_existing.contract_version <> p_contract_version
  ) then
    return jsonb_build_object(
      'allowed', false,
      'duplicate', true,
      'conflict', true,
      'state', v_existing.state,
      'reason', 'idempotency_conflict'
    );
  end if;

  v_result := public.reserve_ai_usage(
    p_user_id,
    p_request_key,
    p_credit_amount,
    p_request_fingerprint
  );

  update public.ai_usage_requests
  set contract_version = p_contract_version
  where user_id = p_user_id and request_key = p_request_key;

  if coalesce((v_result ->> 'duplicate')::boolean, false)
    and v_existing.response_expires_at is not null
    and v_existing.response_expires_at <= now() then
    v_result := (v_result - 'responsePayload') || jsonb_build_object(
      'responsePayload', '{}'::jsonb,
      'responseExpired', true
    );
  end if;

  return v_result || jsonb_build_object(
    'requestFingerprint', p_request_fingerprint,
    'contractVersion', p_contract_version
  );
end;
$$;

create or replace function public.settle_ai_usage_v2(
  p_user_id uuid,
  p_request_key text,
  p_succeeded boolean,
  p_input_tokens integer default null,
  p_output_tokens integer default null,
  p_provider_request_id text default null,
  p_failure_code text default null,
  p_response_payload jsonb default '{}'::jsonb,
  p_response_ttl interval default interval '15 minutes'
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if p_response_ttl < interval '1 minute'
    or p_response_ttl > interval '1 hour' then
    raise exception 'invalid AI response retention interval';
  end if;

  v_result := public.settle_ai_usage(
    p_user_id,
    p_request_key,
    p_succeeded,
    p_input_tokens,
    p_output_tokens,
    p_provider_request_id,
    p_failure_code,
    case when p_succeeded then p_response_payload else '{}'::jsonb end
  );

  update public.ai_usage_requests
  set response_expires_at = case
        when p_succeeded then now() + p_response_ttl
        else null
      end,
      response_payload = case
        when p_succeeded then response_payload
        else '{}'::jsonb
      end
  where user_id = p_user_id and request_key = p_request_key;

  return v_result;
end;
$$;

create or replace function public.purge_expired_ai_response_payloads()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_count integer;
begin
  update public.ai_usage_requests
  set response_payload = '{}'::jsonb,
      response_expires_at = null
  where response_expires_at is not null
    and response_expires_at <= now()
    and response_payload <> '{}'::jsonb;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.reserve_ai_usage_v2(uuid, text, integer, text, text)
  from public, anon, authenticated, service_role;

revoke all on function public.settle_ai_usage_v2(uuid, text, boolean, integer, integer, text, text, jsonb, interval)
  from public, anon, authenticated, service_role;

revoke all on function public.purge_expired_ai_response_payloads()
  from public, anon, authenticated, service_role;

grant execute on function public.reserve_ai_usage_v2(uuid, text, integer, text, text)
  to service_role;
grant execute on function public.settle_ai_usage_v2(uuid, text, boolean, integer, integer, text, text, jsonb, interval)
  to service_role;

grant execute on function public.purge_expired_ai_response_payloads()
  to service_role;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'chronospark-purge-expired-ai-responses';
  perform cron.schedule(
    'chronospark-purge-expired-ai-responses',
    '*/5 * * * *',
    'select public.purge_expired_ai_response_payloads();'
  );
end;
$$;

alter table public.account_deletion_requests
  add column if not exists receipt_expires_at timestamptz,
  add column if not exists storage_pending_prefixes jsonb not null default '[]'::jsonb,
  add column if not exists last_stage_started_at timestamptz;

update public.account_deletion_requests
set receipt_expires_at = created_at + interval '24 hours'
where receipt_expires_at is null;

alter table public.account_deletion_requests
  alter column receipt_expires_at set default (now() + interval '24 hours'),
  alter column receipt_expires_at set not null;

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conname = 'account_deletion_storage_prefixes_array'
      and conrelid = 'public.account_deletion_requests'::regclass
  ) then
    alter table public.account_deletion_requests
      add constraint account_deletion_storage_prefixes_array
      check (jsonb_typeof(storage_pending_prefixes) = 'array');
  end if;
end;
$$;

create or replace function public.claim_account_deletion_request(
  p_request_id text,
  p_receipt_hash text,
  p_user_id uuid default null,
  p_lease_id uuid default gen_random_uuid(),
  p_allow_internal boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests;
begin
  if p_request_id !~ '^[0-9a-f]{64}$'
    or (not p_allow_internal and p_receipt_hash !~ '^[0-9a-f]{64}$') then
    raise exception 'invalid deletion request';
  end if;
  if not p_allow_internal and p_user_id is null then
    return jsonb_build_object('claimed', false, 'reason', 'authentication_required');
  end if;

  if p_user_id is not null then
    select * into v_request
    from public.account_deletion_requests
    where user_id = p_user_id
    for update;

    if found and v_request.request_id <> p_request_id then
      if v_request.sessions_revoked_at is not null then
        return jsonb_build_object(
          'claimed', false,
          'reason', 'existing_request_after_revocation'
        );
      end if;
      update public.account_deletion_requests
      set request_id = p_request_id,
          receipt_hash = p_receipt_hash,
          receipt_expires_at = now() + interval '24 hours',
          state = 'requested',
          lease_id = null,
          lease_until = null,
          attempts = 0,
          sessions_revoked_at = null,
          storage_deleted_at = null,
          auth_deleted_at = null,
          completed_at = null,
          storage_pending_prefixes = jsonb_build_array(p_user_id::text),
          last_error_code = null,
          updated_at = now()
      where user_id = p_user_id;
    elsif not found then
      insert into public.account_deletion_requests (
        request_id, user_id, receipt_hash, receipt_expires_at, state,
        storage_pending_prefixes, updated_at
      ) values (
        p_request_id, p_user_id, p_receipt_hash, now() + interval '24 hours',
        'requested', jsonb_build_array(p_user_id::text), now()
      ) on conflict (request_id) do nothing;
    end if;
  end if;

  select * into v_request
  from public.account_deletion_requests
  where request_id = p_request_id
    and (
      p_allow_internal
      or (
        p_user_id is not null
        and user_id = p_user_id
        and receipt_hash = p_receipt_hash
        and receipt_expires_at > now()
      )
    )
  for update;

  if not found then
    return jsonb_build_object('claimed', false, 'reason', 'not_found_or_expired');
  end if;
  if v_request.state = 'completed' then
    return jsonb_build_object(
      'claimed', false, 'completed', true, 'state', v_request.state
    );
  end if;
  if v_request.state = 'failed' then
    return jsonb_build_object(
      'claimed', false, 'completed', false, 'state', v_request.state,
      'reason', coalesce(v_request.last_error_code, 'failed')
    );
  end if;
  if v_request.attempts >= 100 then
    update public.account_deletion_requests
    set state = 'failed',
        lease_id = null,
        lease_until = null,
        last_error_code = 'retry_budget_exhausted',
        updated_at = now()
    where request_id = p_request_id;
    return jsonb_build_object(
      'claimed', false, 'completed', false, 'state', 'failed',
      'reason', 'retry_budget_exhausted'
    );
  end if;
  if v_request.lease_until is not null and v_request.lease_until > now() then
    return jsonb_build_object(
      'claimed', false, 'state', v_request.state, 'retry', true
    );
  end if;

  update public.account_deletion_requests
  set lease_id = p_lease_id,
      lease_until = now() + interval '90 seconds',
      attempts = attempts + 1,
      last_stage_started_at = now(),
      updated_at = now()
  where request_id = p_request_id;

  return jsonb_build_object(
    'claimed', true,
    'leaseId', p_lease_id,
    'state', v_request.state,
    'userId', v_request.user_id,
    'sessionsRevoked', v_request.sessions_revoked_at is not null,
    'storageDeleted', v_request.storage_deleted_at is not null,
    'storagePendingPrefixes', v_request.storage_pending_prefixes
  );
end;
$$;

create or replace function public.transition_account_deletion_request(
  p_request_id text,
  p_lease_id uuid,
  p_expected_state text,
  p_next_state text,
  p_storage_pending_prefixes jsonb default null,
  p_last_error_code text default null
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_count integer;
begin
  if p_expected_state not in ('requested', 'sessions_revoked', 'storage_deleted')
    or p_next_state not in ('requested', 'sessions_revoked', 'storage_deleted', 'completed', 'failed')
    or (p_storage_pending_prefixes is not null and jsonb_typeof(p_storage_pending_prefixes) <> 'array') then
    raise exception 'invalid deletion transition';
  end if;
  if not (
    (p_expected_state = 'requested' and p_next_state in ('requested', 'sessions_revoked', 'failed'))
    or (p_expected_state = 'sessions_revoked' and p_next_state in ('sessions_revoked', 'storage_deleted', 'failed'))
    or (p_expected_state = 'storage_deleted' and p_next_state in ('storage_deleted', 'completed', 'failed'))
  ) then
    raise exception 'disallowed deletion transition';
  end if;

  update public.account_deletion_requests
  set state = p_next_state,
      storage_pending_prefixes = coalesce(
        p_storage_pending_prefixes,
        storage_pending_prefixes
      ),
      sessions_revoked_at = case
        when p_next_state = 'sessions_revoked' then coalesce(sessions_revoked_at, now())
        else sessions_revoked_at
      end,
      storage_deleted_at = case
        when p_next_state = 'storage_deleted' then coalesce(storage_deleted_at, now())
        else storage_deleted_at
      end,
      auth_deleted_at = case
        when p_next_state = 'completed' then coalesce(auth_deleted_at, now())
        else auth_deleted_at
      end,
      completed_at = case
        when p_next_state = 'completed' then coalesce(completed_at, now())
        else completed_at
      end,
      lease_id = null,
      lease_until = null,
      last_error_code = left(p_last_error_code, 100),
      updated_at = now()
  where request_id = p_request_id
    and lease_id = p_lease_id
    and lease_until > now()
    and state = p_expected_state;
  get diagnostics v_count = row_count;
  return v_count = 1;
end;
$$;

create or replace function public.read_account_deletion_status(
  p_request_id text,
  p_receipt_hash text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests;
begin
  if p_request_id !~ '^[0-9a-f]{64}$'
    or p_receipt_hash !~ '^[0-9a-f]{64}$' then
    return null;
  end if;
  select * into v_request
  from public.account_deletion_requests
  where request_id = p_request_id
    and receipt_hash = p_receipt_hash
    and receipt_expires_at > now();
  if not found then return null; end if;
  return jsonb_build_object(
    'accepted', true,
    'completed', v_request.state = 'completed',
    'state', v_request.state,
    'retry', v_request.state not in ('completed', 'failed'),
    'receiptExpiresAt', v_request.receipt_expires_at
  );
end;
$$;

create or replace function public.list_account_deletion_reconcile_candidates(
  p_limit integer default 5
)
returns table(request_id text)
language sql
security invoker
set search_path = ''
as $$
  select request_id
  from public.account_deletion_requests
  where state not in ('completed', 'failed')
    and (lease_until is null or lease_until <= now())
  order by updated_at asc
  limit least(greatest(p_limit, 1), 20);
$$;

revoke all on function public.transition_account_deletion_request(text, uuid, text, text, jsonb, text)
  from public, anon, authenticated, service_role;

revoke all on function public.read_account_deletion_status(text, text)
  from public, anon, authenticated, service_role;

revoke all on function public.list_account_deletion_reconcile_candidates(integer)
  from public, anon, authenticated, service_role;

grant execute on function public.transition_account_deletion_request(text, uuid, text, text, jsonb, text)
  to service_role;

grant execute on function public.read_account_deletion_status(text, text)
  to service_role;

grant execute on function public.list_account_deletion_reconcile_candidates(integer)
  to service_role;

create or replace function public.mark_google_play_rtdn_event(
  p_message_id text,
  p_expected_state text,
  p_next_state text,
  p_failure_code text default null
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_count integer;
begin
  if p_message_id is null or length(p_message_id) not between 1 and 200
    or p_expected_state not in ('received', 'failed')
    or p_next_state not in ('received', 'processed', 'ignored', 'failed') then
    raise exception 'invalid RTDN transition';
  end if;
  update public.google_play_rtdn_events
  set state = p_next_state,
      failure_code = left(p_failure_code, 100),
      processed_at = case
        when p_next_state in ('processed', 'ignored') then now()
        else null
      end
  where message_id = p_message_id and state = p_expected_state;
  get diagnostics v_count = row_count;
  return v_count = 1;
end;
$$;

create or replace function public.reconcile_google_play_one_time(
  p_purchase_token_hash text,
  p_product_id text,
  p_order_id text,
  p_event_key text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_result jsonb;
begin
  if p_product_id not in (
    'chronospark_lifetime',
    'chronospark_credits_100',
    'chronospark_credits_500',
    'chronospark_credits_1200',
    'chronospark_credits_3000'
  ) then
    return jsonb_build_object('applied', false, 'reason', 'unsupported_product');
  end if;
  select * into v_binding
  from public.purchase_bindings
  where token_hash = p_purchase_token_hash
  for update;
  if not found or v_binding.product_id <> p_product_id then
    return jsonb_build_object('applied', false, 'reason', 'binding_not_found');
  end if;
  if p_event_key is not null and exists (
    select 1 from public.monetization_entitlement_events
    where event_key = p_event_key
  ) then
    return jsonb_build_object(
      'applied', true, 'duplicate', true, 'userId', v_binding.user_id
    );
  end if;

  v_result := public.apply_verified_purchase(
    v_binding.user_id,
    p_product_id,
    'inapp',
    p_purchase_token_hash,
    p_order_id,
    now(),
    null,
    p_payload || jsonb_build_object('_edge_event_key', p_event_key)
  );

  update public.monetization_entitlement_events
  set event_key = p_event_key
  where user_id = v_binding.user_id
    and event_key is null
    and metadata ->> '_edge_event_key' = p_event_key;

  return coalesce(v_result, '{}'::jsonb) || jsonb_build_object(
    'userId', v_binding.user_id
  );
end;
$$;

create or replace function public.migrate_google_play_purchase_binding(
  p_old_purchase_token_hash text,
  p_new_purchase_token_hash text,
  p_product_id text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_old public.purchase_bindings;
  v_new public.purchase_bindings;
begin
  if p_old_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or p_new_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or p_product_id not in (
      'chronospark_premium_monthly', 'chronospark_premium_annual'
    ) then
    return jsonb_build_object('migrated', false, 'reason', 'invalid_input');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_old_purchase_token_hash, 0));
  select * into v_old
  from public.purchase_bindings
  where token_hash = p_old_purchase_token_hash;
  if not found then
    return jsonb_build_object('migrated', false, 'reason', 'old_binding_not_found');
  end if;

  insert into public.purchase_bindings (token_hash, user_id, product_id)
  values (p_new_purchase_token_hash, v_old.user_id, p_product_id)
  on conflict (token_hash) do nothing;

  select * into v_new
  from public.purchase_bindings
  where token_hash = p_new_purchase_token_hash;
  if not found or v_new.user_id <> v_old.user_id then
    return jsonb_build_object('migrated', false, 'reason', 'binding_conflict');
  end if;
  return jsonb_build_object('migrated', true, 'userId', v_old.user_id);
end;
$$;

revoke all on function public.mark_google_play_rtdn_event(text, text, text, text)
  from public, anon, authenticated, service_role;

revoke all on function public.reconcile_google_play_one_time(text, text, text, text, jsonb)
  from public, anon, authenticated, service_role;

revoke all on function public.migrate_google_play_purchase_binding(text, text, text)
  from public, anon, authenticated, service_role;

grant execute on function public.mark_google_play_rtdn_event(text, text, text, text)
  to service_role;

grant execute on function public.reconcile_google_play_one_time(text, text, text, text, jsonb)
  to service_role;

grant execute on function public.migrate_google_play_purchase_binding(text, text, text)
  to service_role;
