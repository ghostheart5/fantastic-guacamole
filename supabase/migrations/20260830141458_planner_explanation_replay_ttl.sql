-- Durable quote binding and short-lived response replay for the optional
-- Smart Planner explanation surface. Raw explanation content is isolated from
-- the client-readable billing table and expires after four minutes. The
-- minute-level scrub job then removes it within the disclosed five-minute
-- target under normal scheduler operation.

create table public.planner_explanation_quotes (
  quote_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_key text not null,
  quote_fingerprint text not null check (quote_fingerprint ~ '^[0-9a-f]{64}$'),
  input_fingerprint text not null check (input_fingerprint ~ '^[0-9a-f]{64}$'),
  expected_credits integer not null check (expected_credits between 1 and 3),
  model_id text not null check (char_length(model_id) between 1 and 100),
  model_label text not null check (char_length(model_label) between 1 and 100),
  prompt_version text not null check (char_length(prompt_version) between 1 and 100),
  response_schema_version integer not null check (response_schema_version = 1),
  disclosure_version integer not null check (disclosure_version = 1),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique (user_id, request_key),
  constraint planner_explanation_quote_ttl_check
    check (expires_at > created_at and expires_at <= created_at + interval '5 minutes')
);

create index planner_explanation_quotes_expiry_idx
  on public.planner_explanation_quotes (expires_at);

create table public.planner_explanation_replays (
  user_id uuid not null,
  request_key text not null,
  response_payload jsonb not null,
  content_expires_at timestamptz not null,
  content_scrubbed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, request_key),
  foreign key (user_id, request_key)
    references public.ai_usage_requests (user_id, request_key)
    on delete cascade,
  constraint planner_explanation_replay_payload_object_check
    check (jsonb_typeof(response_payload) = 'object'),
  constraint planner_explanation_replay_ttl_check
    check (
      content_expires_at > created_at
      and content_expires_at <= created_at + interval '4 minutes'
    )
);

create index planner_explanation_replays_expiry_idx
  on public.planner_explanation_replays (content_expires_at)
  where content_scrubbed_at is null;

alter table public.planner_explanation_quotes enable row level security;
alter table public.planner_explanation_replays enable row level security;

revoke all on table public.planner_explanation_quotes
  from public, anon, authenticated, service_role;
revoke all on table public.planner_explanation_replays
  from public, anon, authenticated, service_role;

grant select, insert, update, delete on table public.planner_explanation_quotes
  to service_role;
grant select, insert, update, delete on table public.planner_explanation_replays
  to service_role;

create or replace function public.issue_planner_explanation_quote(
  p_user_id uuid,
  p_request_key text,
  p_quote_fingerprint text,
  p_input_fingerprint text,
  p_expected_credits integer,
  p_model_id text,
  p_model_label text,
  p_prompt_version text,
  p_response_schema_version integer,
  p_disclosure_version integer
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_quote public.planner_explanation_quotes;
  v_now timestamptz := now();
begin
  if p_user_id is null
    or p_request_key !~ '^[A-Za-z0-9._:=+-]{8,200}$'
    or p_quote_fingerprint !~ '^[0-9a-f]{64}$'
    or p_input_fingerprint !~ '^[0-9a-f]{64}$'
    or p_expected_credits not between 1 and 3
    or char_length(p_model_id) not between 1 and 100
    or char_length(p_model_label) not between 1 and 100
    or char_length(p_prompt_version) not between 1 and 100
    or p_response_schema_version <> 1
    or p_disclosure_version <> 1 then
    raise exception 'invalid planner explanation quote';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'chronospark:planner-explanation-quote:' || p_user_id::text || ':' || p_request_key,
      0
    )
  );
  select * into v_quote
  from public.planner_explanation_quotes
  where user_id = p_user_id and request_key = p_request_key
  for update;

  if found then
    if v_quote.quote_fingerprint <> p_quote_fingerprint
      or v_quote.input_fingerprint <> p_input_fingerprint
      or v_quote.expected_credits <> p_expected_credits
      or v_quote.model_id <> p_model_id
      or v_quote.model_label <> p_model_label
      or v_quote.prompt_version <> p_prompt_version
      or v_quote.response_schema_version <> p_response_schema_version
      or v_quote.disclosure_version <> p_disclosure_version then
      return jsonb_build_object(
        'issued', false,
        'reason', 'idempotency_mismatch'
      );
    end if;
    if v_quote.expires_at <= v_now then
      return jsonb_build_object('issued', false, 'reason', 'quote_expired');
    end if;
    return jsonb_build_object(
      'issued', true,
      'duplicate', true,
      'quoteId', v_quote.quote_id,
      'expiresAt', v_quote.expires_at
    );
  end if;

  insert into public.planner_explanation_quotes (
    user_id,
    request_key,
    quote_fingerprint,
    input_fingerprint,
    expected_credits,
    model_id,
    model_label,
    prompt_version,
    response_schema_version,
    disclosure_version,
    created_at,
    expires_at
  ) values (
    p_user_id,
    p_request_key,
    p_quote_fingerprint,
    p_input_fingerprint,
    p_expected_credits,
    p_model_id,
    p_model_label,
    p_prompt_version,
    p_response_schema_version,
    p_disclosure_version,
    v_now,
    v_now + interval '5 minutes'
  ) returning * into v_quote;

  return jsonb_build_object(
    'issued', true,
    'duplicate', false,
    'quoteId', v_quote.quote_id,
    'expiresAt', v_quote.expires_at
  );
end;
$$;

create or replace function public.verify_planner_explanation_quote(
  p_user_id uuid,
  p_request_key text,
  p_quote_id uuid,
  p_input_fingerprint text,
  p_expected_credits integer,
  p_disclosure_version integer,
  p_model_id text,
  p_model_label text,
  p_prompt_version text,
  p_response_schema_version integer
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_quote public.planner_explanation_quotes;
begin
  if p_user_id is null
    or p_request_key !~ '^[A-Za-z0-9._:=+-]{8,200}$'
    or p_quote_id is null
    or p_input_fingerprint !~ '^[0-9a-f]{64}$'
    or p_expected_credits not between 1 and 3
    or p_disclosure_version <> 1
    or p_response_schema_version <> 1 then
    raise exception 'invalid planner explanation quote verification';
  end if;

  select * into v_quote
  from public.planner_explanation_quotes
  where user_id = p_user_id
    and request_key = p_request_key
    and quote_id = p_quote_id;
  if not found then
    return jsonb_build_object('valid', false, 'reason', 'quote_not_found');
  end if;
  if v_quote.expires_at <= now() then
    return jsonb_build_object('valid', false, 'reason', 'quote_expired');
  end if;
  if v_quote.input_fingerprint <> p_input_fingerprint
    or v_quote.expected_credits <> p_expected_credits
    or v_quote.disclosure_version <> p_disclosure_version
    or v_quote.model_id <> p_model_id
    or v_quote.model_label <> p_model_label
    or v_quote.prompt_version <> p_prompt_version
    or v_quote.response_schema_version <> p_response_schema_version then
    return jsonb_build_object('valid', false, 'reason', 'idempotency_mismatch');
  end if;
  return jsonb_build_object('valid', true, 'expiresAt', v_quote.expires_at);
end;
$$;

create or replace function public.settle_planner_explanation_usage(
  p_user_id uuid,
  p_request_key text,
  p_succeeded boolean,
  p_input_tokens integer default null,
  p_output_tokens integer default null,
  p_provider_request_id text default null,
  p_failure_code text default null,
  p_response_payload jsonb default '{}'::jsonb,
  p_content_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_usage public.ai_usage_requests;
  v_wallet public.monetization_wallets;
  v_result jsonb;
  v_metadata jsonb;
  v_now timestamptz := now();
begin
  select * into v_usage
  from public.ai_usage_requests
  where user_id = p_user_id and request_key = p_request_key
  for update;
  if not found then
    raise exception 'planner explanation reservation not found';
  end if;

  if not p_succeeded then
    return public.settle_ai_usage(
      p_user_id,
      p_request_key,
      false,
      p_input_tokens,
      p_output_tokens,
      p_provider_request_id,
      p_failure_code,
      '{}'::jsonb
    );
  end if;

  select * into v_wallet
  from public.monetization_wallets
  where user_id = p_user_id;
  if not found then
    raise exception 'planner explanation wallet not found';
  end if;
  if p_content_expires_at is null
    or p_content_expires_at <= v_now
    or p_content_expires_at > v_now + interval '4 minutes'
    or jsonb_typeof(p_response_payload) <> 'object'
    or (
      select count(*)
      from pg_catalog.jsonb_object_keys(p_response_payload)
    ) <> 17
    or not (p_response_payload ?& array[
      'schemaVersion', 'operation', 'surface', 'requestId', 'status',
      'responseDigest', 'explanation', 'sourceClauseIds', 'provider',
      'modelLabel', 'promptVersion', 'responseSchemaVersion',
      'expectedCredits', 'creditsCharged', 'remainingCredits',
      'contentExpiresAt', 'replayState'
    ])
    or p_response_payload ->> 'schemaVersion' <> '1'
    or p_response_payload ->> 'operation' <> 'execute'
    or p_response_payload ->> 'surface' <> 'smart_planner_explanation'
    or p_response_payload ->> 'requestId' <> p_request_key
    or p_response_payload ->> 'status' <> 'completed'
    or p_response_payload ->> 'responseDigest' !~ '^[0-9a-f]{64}$'
    or jsonb_typeof(p_response_payload -> 'explanation') <> 'string'
    or char_length(p_response_payload ->> 'explanation') not between 1 and 1200
    or jsonb_typeof(p_response_payload -> 'sourceClauseIds') <> 'array'
    or jsonb_array_length(p_response_payload -> 'sourceClauseIds') < 1
    or p_response_payload ->> 'provider' <> 'Anthropic'
    or p_response_payload ->> 'responseSchemaVersion' <> '1'
    or (p_response_payload ->> 'expectedCredits')::integer <> v_usage.credit_amount
    or (p_response_payload ->> 'creditsCharged')::integer <> v_usage.credit_amount
    or (p_response_payload ->> 'remainingCredits')::integer <> v_wallet.balance
    or (p_response_payload ->> 'contentExpiresAt')::timestamptz
      <> p_content_expires_at
    or p_response_payload ->> 'replayState' <> 'fresh' then
    raise exception 'invalid planner explanation completion payload';
  end if;

  v_metadata :=
    (p_response_payload - array['explanation', 'sourceClauseIds', 'contentExpiresAt']::text[])
    || jsonb_build_object(
      'status', 'replay_expired',
      'creditsCharged', 0,
      'replayState', 'content_scrubbed'
    );

  v_result := public.settle_ai_usage(
    p_user_id,
    p_request_key,
    true,
    p_input_tokens,
    p_output_tokens,
    p_provider_request_id,
    null,
    v_metadata
  );
  if v_result ->> 'state' = 'completed'
    and coalesce((v_result ->> 'duplicate')::boolean, false) = false then
    insert into public.planner_explanation_replays (
      user_id,
      request_key,
      response_payload,
      content_expires_at,
      created_at,
      updated_at
    ) values (
      p_user_id,
      p_request_key,
      p_response_payload,
      p_content_expires_at,
      v_now,
      v_now
    );
  end if;
  return v_result;
end;
$$;

create or replace function public.load_planner_explanation_replay(
  p_user_id uuid,
  p_request_key text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_replay public.planner_explanation_replays;
begin
  select * into v_replay
  from public.planner_explanation_replays
  where user_id = p_user_id and request_key = p_request_key
  for update;
  if not found then
    return jsonb_build_object('found', false);
  end if;
  if v_replay.content_scrubbed_at is null
    and v_replay.content_expires_at <= now() then
    update public.planner_explanation_replays
    set response_payload =
        (response_payload - array['explanation', 'sourceClauseIds', 'contentExpiresAt']::text[])
        || jsonb_build_object(
          'status', 'replay_expired',
          'creditsCharged', 0,
          'replayState', 'content_scrubbed'
        ),
      content_scrubbed_at = now(),
      updated_at = now()
    where user_id = p_user_id and request_key = p_request_key
    returning * into v_replay;
  end if;
  return jsonb_build_object(
    'found', true,
    'scrubbed', v_replay.content_scrubbed_at is not null,
    'responsePayload', v_replay.response_payload
  );
end;
$$;

create or replace function public.scrub_planner_explanation_replay(
  p_user_id uuid,
  p_request_key text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_replay public.planner_explanation_replays;
begin
  select * into v_replay
  from public.planner_explanation_replays
  where user_id = p_user_id and request_key = p_request_key
  for update;
  if not found then
    return jsonb_build_object('scrubbed', false, 'reason', 'replay_not_found');
  end if;
  if v_replay.content_scrubbed_at is not null then
    return jsonb_build_object('scrubbed', true, 'duplicate', true);
  end if;
  if v_replay.content_expires_at > now() then
    return jsonb_build_object('scrubbed', false, 'reason', 'replay_not_expired');
  end if;
  update public.planner_explanation_replays
  set response_payload =
      (response_payload - array['explanation', 'sourceClauseIds', 'contentExpiresAt']::text[])
      || jsonb_build_object(
        'status', 'replay_expired',
        'creditsCharged', 0,
        'replayState', 'content_scrubbed'
      ),
    content_scrubbed_at = now(),
    updated_at = now()
  where user_id = p_user_id and request_key = p_request_key;
  return jsonb_build_object('scrubbed', true, 'duplicate', false);
end;
$$;

create or replace function public.scrub_expired_ai_response_content()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_count integer;
begin
  update public.planner_explanation_replays
  set response_payload =
      (response_payload - array['explanation', 'sourceClauseIds', 'contentExpiresAt']::text[])
      || jsonb_build_object(
        'status', 'replay_expired',
        'creditsCharged', 0,
        'replayState', 'content_scrubbed'
      ),
    content_scrubbed_at = now(),
    updated_at = now()
  where content_scrubbed_at is null and content_expires_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.issue_planner_explanation_quote(
  uuid, text, text, text, integer, text, text, text, integer, integer
) from public, anon, authenticated, service_role;
revoke all on function public.verify_planner_explanation_quote(
  uuid, text, uuid, text, integer, integer, text, text, text, integer
) from public, anon, authenticated, service_role;
revoke all on function public.settle_planner_explanation_usage(
  uuid, text, boolean, integer, integer, text, text, jsonb, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.load_planner_explanation_replay(uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.scrub_planner_explanation_replay(uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.scrub_expired_ai_response_content()
  from public, anon, authenticated, service_role;

grant execute on function public.issue_planner_explanation_quote(
  uuid, text, text, text, integer, text, text, text, integer, integer
) to service_role;
grant execute on function public.verify_planner_explanation_quote(
  uuid, text, uuid, text, integer, integer, text, text, text, integer
) to service_role;
grant execute on function public.settle_planner_explanation_usage(
  uuid, text, boolean, integer, integer, text, text, jsonb, timestamptz
) to service_role;
grant execute on function public.load_planner_explanation_replay(uuid, text)
  to service_role;
grant execute on function public.scrub_planner_explanation_replay(uuid, text)
  to service_role;
grant execute on function public.scrub_expired_ai_response_content()
  to service_role;

create extension if not exists pg_cron;

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname = 'chronospark-scrub-expired-ai-response-content'
  loop
    perform cron.unschedule(v_job_id);
  end loop;

  perform cron.schedule(
    'chronospark-scrub-expired-ai-response-content',
    '* * * * *',
    'select public.scrub_expired_ai_response_content();'
  );
exception
  when others then
    raise exception 'failed to configure AI response scrub job: %', sqlerrm;
end;
$$;
