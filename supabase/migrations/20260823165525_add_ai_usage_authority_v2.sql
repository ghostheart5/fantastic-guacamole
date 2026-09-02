-- P0-06: make AI admission an atomic, server-only authority boundary.
-- Provider cost values are conservative accounting estimates in micro-USD,
-- based on the pinned Sonnet policy ($3/MTok input, $15/MTok output). They are
-- not provider invoices.

do $p0_preflight$
begin
  if to_regclass('auth.users') is null
    or to_regclass('public.monetization_subscription_statuses') is null
    or to_regclass('public.monetization_wallets') is null
    or to_regclass('public.monetization_credit_transactions') is null
    or to_regprocedure('public.ensure_monetization_wallet(uuid)') is null
    or to_regprocedure('public.reset_monetization_allowance(uuid)') is null then
    raise exception using message =
      'P0-06 preflight failed: required monetization/auth baseline is missing';
  end if;

  if not has_table_privilege(
      'service_role', 'public.monetization_subscription_statuses', 'SELECT'
    )
    or not has_table_privilege(
      'service_role', 'public.monetization_wallets', 'SELECT'
    )
    or not has_table_privilege(
      'service_role', 'public.monetization_wallets', 'INSERT'
    )
    or not has_table_privilege(
      'service_role', 'public.monetization_wallets', 'UPDATE'
    )
    or not has_table_privilege(
      'service_role', 'public.monetization_credit_transactions', 'INSERT'
    )
    or not has_function_privilege(
      'service_role', 'public.ensure_monetization_wallet(uuid)', 'EXECUTE'
    )
    or not has_function_privilege(
      'service_role', 'public.reset_monetization_allowance(uuid)', 'EXECUTE'
    ) then
    raise exception using message =
      'P0-06 preflight failed: service_role lacks required monetization privileges';
  end if;

  if to_regclass('public.ai_usage_requests') is not null then
    if exists (
      with expected(column_name, column_type) as (
        values
          ('id', 'uuid'::regtype),
          ('user_id', 'uuid'::regtype),
          ('request_key', 'text'::regtype),
          ('state', 'text'::regtype),
          ('credit_amount', 'integer'::regtype),
          ('bonus_used', 'integer'::regtype),
          ('allowance_used', 'integer'::regtype),
          ('prompt_hash', 'text'::regtype),
          ('provider_request_id', 'text'::regtype),
          ('input_tokens', 'integer'::regtype),
          ('output_tokens', 'integer'::regtype),
          ('response_payload', 'jsonb'::regtype),
          ('failure_code', 'text'::regtype),
          ('created_at', 'timestamptz'::regtype),
          ('settled_at', 'timestamptz'::regtype)
      )
      select 1
      from expected
      left join pg_catalog.pg_attribute as attribute
        on attribute.attrelid = 'public.ai_usage_requests'::regclass
        and attribute.attname = expected.column_name
        and attribute.attnum > 0
        and not attribute.attisdropped
      where attribute.attname is null
        or attribute.atttypid <> expected.column_type
    ) then
      raise exception using message =
        'P0-06 preflight failed: public.ai_usage_requests has missing or incompatible baseline columns';
    end if;
  end if;
end;
$p0_preflight$;
create table if not exists public.ai_usage_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_key text not null,
  state text not null
    check (state in ('reserved', 'completed', 'refunded', 'denied')),
  credit_amount integer not null check (credit_amount between 1 and 3),
  bonus_used integer not null default 0 check (bonus_used >= 0),
  allowance_used integer not null default 0 check (allowance_used >= 0),
  prompt_hash text not null,
  provider_request_id text,
  input_tokens integer,
  output_tokens integer,
  response_payload jsonb not null default '{}'::jsonb,
  failure_code text,
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  unique (user_id, request_key)
);
do $p0_baseline_assert$
declare
  v_problem text;
begin
  select pg_catalog.string_agg(expected.column_name, ', ' order by expected.column_name)
  into v_problem
  from (
    values
      ('id'),
      ('user_id'),
      ('request_key'),
      ('state'),
      ('credit_amount'),
      ('bonus_used'),
      ('allowance_used'),
      ('prompt_hash'),
      ('response_payload'),
      ('created_at')
  ) as expected(column_name)
  left join pg_catalog.pg_attribute as attribute
    on attribute.attrelid = 'public.ai_usage_requests'::regclass
    and attribute.attname = expected.column_name
    and attribute.attnum > 0
    and not attribute.attisdropped
  where not coalesce(attribute.attnotnull, false);

  if v_problem is not null then
    raise exception using message =
      'P0-06 preflight failed: required ai_usage_requests columns are nullable: '
      || v_problem;
  end if;

  select pg_catalog.string_agg(expected.column_name, ', ' order by expected.column_name)
  into v_problem
  from (
    values ('id'), ('bonus_used'), ('allowance_used'), ('response_payload'), ('created_at')
  ) as expected(column_name)
  join pg_catalog.pg_attribute as attribute
    on attribute.attrelid = 'public.ai_usage_requests'::regclass
    and attribute.attname = expected.column_name
    and attribute.attnum > 0
    and not attribute.attisdropped
  where not attribute.atthasdef;

  if v_problem is not null then
    raise exception using message =
      'P0-06 preflight failed: required ai_usage_requests defaults are missing: '
      || v_problem;
  end if;

  select pg_catalog.string_agg(
    attribute.attname,
    ', ' order by attribute.attname
  )
  into v_problem
  from pg_catalog.pg_attribute as attribute
  join pg_catalog.pg_attrdef as default_record
    on default_record.adrelid = attribute.attrelid
    and default_record.adnum = attribute.attnum
  where attribute.attrelid = 'public.ai_usage_requests'::regclass
    and attribute.attname in (
      'id', 'bonus_used', 'allowance_used', 'response_payload', 'created_at'
    )
    and not case attribute.attname
      when 'id' then pg_catalog.pg_get_expr(
        default_record.adbin,
        default_record.adrelid
      ) like '%gen_random_uuid()%'
      when 'bonus_used' then pg_catalog.pg_get_expr(
        default_record.adbin,
        default_record.adrelid
      ) in ('0', '0::integer')
      when 'allowance_used' then pg_catalog.pg_get_expr(
        default_record.adbin,
        default_record.adrelid
      ) in ('0', '0::integer')
      when 'response_payload' then pg_catalog.pg_get_expr(
        default_record.adbin,
        default_record.adrelid
      ) = '''{}''::jsonb'
      when 'created_at' then pg_catalog.pg_get_expr(
        default_record.adbin,
        default_record.adrelid
      ) in ('now()', 'CURRENT_TIMESTAMP')
      else false
    end;

  if v_problem is not null then
    raise exception using message =
      'P0-06 preflight failed: required ai_usage_requests defaults are incompatible: '
      || v_problem;
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.ai_usage_requests'::regclass
      and constraint_record.contype = 'p'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid)
        = 'PRIMARY KEY (id)'
  ) then
    raise exception using message =
      'P0-06 preflight failed: ai_usage_requests primary key must be id';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.ai_usage_requests'::regclass
      and constraint_record.contype = 'u'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid)
        = 'UNIQUE (user_id, request_key)'
  ) then
    raise exception using message =
      'P0-06 preflight failed: ai_usage_requests requires unique (user_id, request_key)';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.ai_usage_requests'::regclass
      and constraint_record.contype = 'f'
      and constraint_record.confrelid = 'auth.users'::regclass
      and constraint_record.confdeltype = 'c'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid)
        like 'FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE%'
  ) then
    raise exception using message =
      'P0-06 preflight failed: ai_usage_requests user ownership must cascade from auth.users';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.ai_usage_requests'::regclass
      and constraint_record.contype = 'c'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like '%state%'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like '%reserved%'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like '%completed%'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like '%refunded%'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like '%denied%'
  ) then
    raise exception using message =
      'P0-06 preflight failed: ai_usage_requests state constraint is incompatible';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.ai_usage_requests'::regclass
      and constraint_record.contype = 'c'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid)
        like '%credit_amount%'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like '%1%'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like '%3%'
  ) then
    raise exception using message =
      'P0-06 preflight failed: ai_usage_requests credit constraint is incompatible';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.ai_usage_requests'::regclass
      and constraint_record.contype = 'c'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid)
        like '%bonus_used%'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like '%0%'
  ) or not exists (
    select 1
    from pg_catalog.pg_constraint as constraint_record
    where constraint_record.conrelid = 'public.ai_usage_requests'::regclass
      and constraint_record.contype = 'c'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid)
        like '%allowance_used%'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like '%0%'
  ) then
    raise exception using message =
      'P0-06 preflight failed: ai_usage_requests usage constraints are incompatible';
  end if;
end;
$p0_baseline_assert$;
create index if not exists ai_usage_requests_user_created_idx
  on public.ai_usage_requests (user_id, created_at desc);
create index if not exists ai_usage_requests_reserved_idx
  on public.ai_usage_requests (created_at)
  where state = 'reserved';
alter table public.ai_usage_requests enable row level security;
revoke all on table public.ai_usage_requests
  from public, anon, authenticated, service_role;
grant select on table public.ai_usage_requests to authenticated;
grant select, insert, update on table public.ai_usage_requests to service_role;
drop policy if exists "ai usage requests select own"
  on public.ai_usage_requests;
create policy "ai usage requests select own"
on public.ai_usage_requests for select to authenticated
using ((select auth.uid()) = user_id);
-- Temporary compatibility admission for an old Edge deployment. The v2 Edge
-- uses admit_ai_usage_v2; service execution is revoked after observed cutover.
create or replace function public.reserve_ai_usage(
  p_user_id uuid,
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
  v_bonus_used integer;
  v_allowance_used integer;
  v_user_daily integer;
  v_global_daily integer;
begin
  if p_user_id is null
    or p_request_key !~ '^[A-Za-z0-9._:-]{8,128}$'
    or p_credit_amount not between 1 and 3
    or p_prompt_hash !~ '^[0-9a-f]{64}$' then
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

  if found then
    return jsonb_build_object(
      'allowed', v_existing.state in ('reserved', 'completed'),
      'state', v_existing.state,
      'duplicate', true,
      'creditAmount', v_existing.credit_amount,
      'responsePayload', v_existing.response_payload
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:legacy-ai-daily-budget', 0)
  );

  select coalesce(sum(credit_amount), 0)::integer into v_user_daily
  from public.ai_usage_requests
  where user_id = p_user_id
    and created_at >= now() - interval '24 hours'
    and state in ('reserved', 'completed');

  select coalesce(sum(credit_amount), 0)::integer into v_global_daily
  from public.ai_usage_requests
  where created_at >= now() - interval '24 hours'
    and state in ('reserved', 'completed');

  if v_user_daily + p_credit_amount > 200
    or v_global_daily + p_credit_amount > 20000 then
    insert into public.ai_usage_requests (
      user_id, request_key, state, credit_amount, prompt_hash,
      failure_code, settled_at
    ) values (
      p_user_id, p_request_key, 'denied', p_credit_amount, p_prompt_hash,
      'daily_budget_exceeded', now()
    );
    return jsonb_build_object(
      'allowed', false,
      'state', 'denied',
      'reason', 'daily_budget_exceeded'
    );
  end if;

  perform public.ensure_monetization_wallet(p_user_id);
  select * into v_wallet
  from public.monetization_wallets
  where user_id = p_user_id
  for update;

  if v_wallet.period_ends_at is not null and v_wallet.period_ends_at <= now() then
    perform public.reset_monetization_allowance(p_user_id);
    select * into v_wallet
    from public.monetization_wallets
    where user_id = p_user_id
    for update;
  end if;

  if v_wallet.balance < p_credit_amount then
    insert into public.ai_usage_requests (
      user_id, request_key, state, credit_amount, prompt_hash,
      failure_code, settled_at
    ) values (
      p_user_id, p_request_key, 'denied', p_credit_amount, p_prompt_hash,
      'insufficient_credits', now()
    );
    return jsonb_build_object(
      'allowed', false,
      'state', 'denied',
      'reason', 'insufficient_credits',
      'balance', v_wallet.balance
    );
  end if;

  v_bonus_used := least(v_wallet.bonus_balance, p_credit_amount);
  v_allowance_used := p_credit_amount - v_bonus_used;

  update public.monetization_wallets as wallet
  set bonus_balance = wallet.bonus_balance - v_bonus_used,
      allowance_remaining = greatest(
        wallet.allowance_remaining - v_allowance_used,
        0
      ),
      balance = wallet.balance - p_credit_amount,
      lifetime_spent = wallet.lifetime_spent + p_credit_amount,
      updated_at = now()
  where wallet.user_id = p_user_id
  returning * into v_wallet;

  insert into public.ai_usage_requests (
    user_id, request_key, state, credit_amount, bonus_used,
    allowance_used, prompt_hash
  ) values (
    p_user_id, p_request_key, 'reserved', p_credit_amount, v_bonus_used,
    v_allowance_used, p_prompt_hash
  );

  insert into public.monetization_credit_transactions (
    user_id, type, amount, balance_after, source, description, metadata
  ) values (
    p_user_id, 'spend', -p_credit_amount, v_wallet.balance, 'ai_proxy',
    'Legacy AI request reserved',
    jsonb_build_object('request_key', p_request_key)
  );

  return jsonb_build_object(
    'allowed', true,
    'state', 'reserved',
    'duplicate', false,
    'creditAmount', p_credit_amount,
    'balance', v_wallet.balance
  );
end;
$$;
alter table public.ai_usage_requests
  add column if not exists contract_version text,
  add column if not exists model_key text,
  add column if not exists prompt_version text,
  add column if not exists access_tier text,
  add column if not exists input_byte_count integer,
  add column if not exists requested_max_output_tokens integer,
  add column if not exists approved_max_output_tokens integer,
  add column if not exists funding_period_ends_at timestamptz,
  add column if not exists reserved_provider_cost_microusd bigint,
  add column if not exists accounted_provider_cost_microusd bigint,
  add column if not exists budget_day_started_at timestamptz;
alter table public.ai_usage_requests
  drop constraint if exists ai_usage_requests_input_byte_count_check,
  add constraint ai_usage_requests_input_byte_count_check
    check (input_byte_count is null or input_byte_count between 1 and 100000),
  drop constraint if exists ai_usage_requests_requested_max_output_tokens_check,
  add constraint ai_usage_requests_requested_max_output_tokens_check
    check (
      requested_max_output_tokens is null
      or requested_max_output_tokens between 128 and 1024
    ),
  drop constraint if exists ai_usage_requests_approved_max_output_tokens_check,
  add constraint ai_usage_requests_approved_max_output_tokens_check
    check (
      approved_max_output_tokens is null
      or approved_max_output_tokens between 128 and 1024
    ),
  drop constraint if exists ai_usage_requests_reserved_provider_cost_check,
  add constraint ai_usage_requests_reserved_provider_cost_check
    check (
      reserved_provider_cost_microusd is null
      or reserved_provider_cost_microusd >= 0
    ),
  drop constraint if exists ai_usage_requests_accounted_provider_cost_check,
  add constraint ai_usage_requests_accounted_provider_cost_check
    check (
      accounted_provider_cost_microusd is null
      or accounted_provider_cost_microusd >= 0
    );
create table if not exists public.ai_usage_budget_windows (
  scope_kind text not null check (scope_kind in ('user', 'global')),
  scope_key text not null,
  user_id uuid references auth.users(id) on delete cascade,
  window_kind text not null check (window_kind in ('minute', 'day')),
  window_started_at timestamptz not null,
  request_count integer not null default 0 check (request_count >= 0),
  reserved_credit_units integer not null default 0
    check (reserved_credit_units >= 0),
  settled_credit_units integer not null default 0
    check (settled_credit_units >= 0),
  reserved_provider_cost_microusd bigint not null default 0
    check (reserved_provider_cost_microusd >= 0),
  accounted_provider_cost_microusd bigint not null default 0
    check (accounted_provider_cost_microusd >= 0),
  updated_at timestamptz not null default now(),
  primary key (scope_kind, scope_key, window_kind, window_started_at),
  check (
    (scope_kind = 'global' and scope_key = 'all' and user_id is null)
    or (
      scope_kind = 'user'
      and user_id is not null
      and scope_key = user_id::text
    )
  )
);
create index if not exists ai_usage_budget_windows_started_idx
  on public.ai_usage_budget_windows (window_started_at);
alter table public.ai_usage_budget_windows enable row level security;
revoke all on table public.ai_usage_budget_windows
  from public, anon, authenticated, service_role;
grant select, insert, update, delete on table public.ai_usage_budget_windows
  to service_role;
-- Preserve the current UTC day's existing credit usage when switching from the
-- aggregate legacy budget to atomic window rows. Legacy rows do not contain
-- provider-cost evidence, so their provider cost is intentionally not guessed.
insert into public.ai_usage_budget_windows (
  scope_kind,
  scope_key,
  user_id,
  window_kind,
  window_started_at,
  request_count,
  reserved_credit_units,
  settled_credit_units,
  updated_at
)
select
  'user',
  usage.user_id::text,
  usage.user_id,
  'day',
  pg_catalog.date_trunc('day', now() at time zone 'UTC') at time zone 'UTC',
  pg_catalog.count(*)::integer,
  coalesce(pg_catalog.sum(usage.credit_amount)
    filter (where usage.state = 'reserved'), 0)::integer,
  coalesce(pg_catalog.sum(usage.credit_amount)
    filter (where usage.state = 'completed'), 0)::integer,
  now()
from public.ai_usage_requests as usage
where usage.created_at >=
  pg_catalog.date_trunc('day', now() at time zone 'UTC') at time zone 'UTC'
  and usage.state in ('reserved', 'completed')
group by usage.user_id
on conflict (scope_kind, scope_key, window_kind, window_started_at)
do nothing;
insert into public.ai_usage_budget_windows (
  scope_kind,
  scope_key,
  user_id,
  window_kind,
  window_started_at,
  request_count,
  reserved_credit_units,
  settled_credit_units,
  updated_at
)
select
  'global',
  'all',
  null,
  'day',
  pg_catalog.date_trunc('day', now() at time zone 'UTC') at time zone 'UTC',
  pg_catalog.count(*)::integer,
  coalesce(pg_catalog.sum(usage.credit_amount)
    filter (where usage.state = 'reserved'), 0)::integer,
  coalesce(pg_catalog.sum(usage.credit_amount)
    filter (where usage.state = 'completed'), 0)::integer,
  now()
from public.ai_usage_requests as usage
where usage.created_at >=
  pg_catalog.date_trunc('day', now() at time zone 'UTC') at time zone 'UTC'
  and usage.state in ('reserved', 'completed')
having pg_catalog.count(*) > 0
on conflict (scope_kind, scope_key, window_kind, window_started_at)
do nothing;
create or replace function public.admit_ai_usage_v2(
  p_user_id uuid,
  p_request_key text,
  p_prompt_hash text,
  p_contract_version text,
  p_model_key text,
  p_prompt_version text,
  p_input_bytes integer,
  p_requested_max_output_tokens integer
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  -- Product policy. A future policy change requires an auditable migration.
  c_contract_version constant text := 'ai-proxy-v2';
  c_model_key constant text := 'claude-sonnet-4-6';
  c_prompt_version constant text := 'chronospark-planner-2026-08-23';
  c_input_cost_per_token_microusd constant bigint := 3;
  c_output_cost_per_token_microusd constant bigint := 15;
  c_user_minute_requests constant integer := 20;
  c_global_minute_requests constant integer := 1000;
  c_user_day_credits constant integer := 200;
  c_global_day_credits constant integer := 20000;
  c_user_day_provider_cost_microusd constant bigint := 10000000;
  c_global_day_provider_cost_microusd constant bigint := 1000000000;

  v_existing public.ai_usage_requests;
  v_wallet public.monetization_wallets;
  v_active_plan text;
  v_access_tier text;
  v_approved_max_output_tokens integer;
  v_credit_amount integer;
  v_reserved_provider_cost_microusd bigint;
  v_bonus_used integer;
  v_allowance_used integer;
  v_minute_start timestamptz;
  v_day_start timestamptz;
  v_user_minute_count integer;
  v_global_minute_count integer;
  v_user_reserved_credits integer;
  v_user_settled_credits integer;
  v_global_reserved_credits integer;
  v_global_settled_credits integer;
  v_user_reserved_cost bigint;
  v_user_accounted_cost bigint;
  v_global_reserved_cost bigint;
  v_global_accounted_cost bigint;
  v_denial_reason text;
begin
  if p_user_id is null
    or p_request_key !~ '^[A-Za-z0-9._:-]{8,128}$'
    or p_prompt_hash !~ '^[0-9a-f]{64}$'
    or p_contract_version <> c_contract_version
    or p_model_key <> c_model_key
    or p_prompt_version <> c_prompt_version
    or p_input_bytes not between 1 and 100000
    or p_requested_max_output_tokens not between 128 and 1024 then
    raise exception 'invalid AI admission request';
  end if;

  -- The per-request transaction lock is acquired before the idempotency read,
  -- so concurrent copies cannot both pass the read and reserve credits.
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

  if found then
    if v_existing.prompt_hash is distinct from p_prompt_hash
      or v_existing.contract_version is distinct from p_contract_version
      or v_existing.model_key is distinct from p_model_key
      or v_existing.prompt_version is distinct from p_prompt_version
      or v_existing.input_byte_count is distinct from p_input_bytes
      or v_existing.requested_max_output_tokens is distinct from
        p_requested_max_output_tokens then
      return jsonb_build_object(
        'allowed', false,
        'duplicate', true,
        'state', v_existing.state,
        'reason', 'idempotency_binding_mismatch'
      );
    end if;

    return jsonb_build_object(
      'allowed', v_existing.state in ('reserved', 'completed'),
      'duplicate', true,
      'state', v_existing.state,
      'reason', v_existing.failure_code,
      'creditAmount', v_existing.credit_amount,
      'responsePayload', v_existing.response_payload,
      'contractVersion', v_existing.contract_version,
      'modelKey', v_existing.model_key,
      'promptVersion', v_existing.prompt_version,
      'accessTier', v_existing.access_tier,
      'approvedMaxOutputTokens', v_existing.approved_max_output_tokens,
      'reservedProviderCostMicrousd',
        v_existing.reserved_provider_cost_microusd
    );
  end if;

  select subscription.plan_id into v_active_plan
  from public.monetization_subscription_statuses as subscription
  where subscription.user_id = p_user_id
    and subscription.is_active = true
    and (
      subscription.expires_at is null
      or subscription.expires_at > now()
    )
  order by subscription.updated_at desc
  limit 1;

  if v_active_plan is null then
    v_access_tier := 'free';
  elsif v_active_plan in ('premium_monthly', 'premium_yearly', 'lifetime') then
    v_access_tier := v_active_plan;
  else
    v_access_tier := 'denied';
  end if;

  v_approved_max_output_tokens := case
    when v_access_tier = 'free'
      then least(p_requested_max_output_tokens, 512)
    when v_access_tier in ('premium_monthly', 'premium_yearly', 'lifetime')
      then p_requested_max_output_tokens
    else 0
  end;

  v_credit_amount := 1
    + case when p_input_bytes > 4096 then 1 else 0 end
    + case when v_approved_max_output_tokens > 512 then 1 else 0 end;
  v_reserved_provider_cost_microusd :=
    (p_input_bytes::bigint * c_input_cost_per_token_microusd)
    + (
      greatest(v_approved_max_output_tokens, 0)::bigint
      * c_output_cost_per_token_microusd
    );
  v_minute_start := pg_catalog.date_trunc('minute', now());
  v_day_start :=
    pg_catalog.date_trunc('day', now() at time zone 'UTC') at time zone 'UTC';

  insert into public.ai_usage_budget_windows (
    scope_kind, scope_key, user_id, window_kind, window_started_at
  ) values
    ('global', 'all', null, 'minute', v_minute_start),
    ('global', 'all', null, 'day', v_day_start),
    ('user', p_user_id::text, p_user_id, 'minute', v_minute_start),
    ('user', p_user_id::text, p_user_id, 'day', v_day_start)
  on conflict (scope_kind, scope_key, window_kind, window_started_at)
  do nothing;

  -- Every caller locks shared/global rows before user rows in the same order.
  perform 1
  from public.ai_usage_budget_windows
  where (scope_kind, scope_key, window_kind, window_started_at) in (
    ('global', 'all', 'minute', v_minute_start),
    ('global', 'all', 'day', v_day_start),
    ('user', p_user_id::text, 'minute', v_minute_start),
    ('user', p_user_id::text, 'day', v_day_start)
  )
  order by scope_kind, scope_key, window_kind, window_started_at
  for update;

  select request_count into v_user_minute_count
  from public.ai_usage_budget_windows
  where scope_kind = 'user'
    and scope_key = p_user_id::text
    and window_kind = 'minute'
    and window_started_at = v_minute_start;
  select request_count into v_global_minute_count
  from public.ai_usage_budget_windows
  where scope_kind = 'global'
    and scope_key = 'all'
    and window_kind = 'minute'
    and window_started_at = v_minute_start;

  update public.ai_usage_budget_windows
  set request_count = request_count + 1,
      updated_at = now()
  where window_kind = 'minute'
    and window_started_at = v_minute_start
    and (
      (scope_kind = 'global' and scope_key = 'all')
      or (scope_kind = 'user' and scope_key = p_user_id::text)
    );

  if v_access_tier = 'denied' then
    v_denial_reason := 'model_access_denied';
  elsif v_user_minute_count + 1 > c_user_minute_requests
    or v_global_minute_count + 1 > c_global_minute_requests then
    v_denial_reason := 'rate_limit_exceeded';
  end if;

  select
    reserved_credit_units,
    settled_credit_units,
    reserved_provider_cost_microusd,
    accounted_provider_cost_microusd
  into
    v_user_reserved_credits,
    v_user_settled_credits,
    v_user_reserved_cost,
    v_user_accounted_cost
  from public.ai_usage_budget_windows
  where scope_kind = 'user'
    and scope_key = p_user_id::text
    and window_kind = 'day'
    and window_started_at = v_day_start;

  select
    reserved_credit_units,
    settled_credit_units,
    reserved_provider_cost_microusd,
    accounted_provider_cost_microusd
  into
    v_global_reserved_credits,
    v_global_settled_credits,
    v_global_reserved_cost,
    v_global_accounted_cost
  from public.ai_usage_budget_windows
  where scope_kind = 'global'
    and scope_key = 'all'
    and window_kind = 'day'
    and window_started_at = v_day_start;

  if v_denial_reason is null and (
    v_user_reserved_credits + v_user_settled_credits + v_credit_amount
      > c_user_day_credits
    or v_global_reserved_credits + v_global_settled_credits + v_credit_amount
      > c_global_day_credits
  ) then
    v_denial_reason := 'daily_credit_budget_exceeded';
  end if;

  if v_denial_reason is null and (
    v_user_reserved_cost + v_user_accounted_cost
      + v_reserved_provider_cost_microusd
      > c_user_day_provider_cost_microusd
    or v_global_reserved_cost + v_global_accounted_cost
      + v_reserved_provider_cost_microusd
      > c_global_day_provider_cost_microusd
  ) then
    v_denial_reason := 'provider_cost_budget_exceeded';
  end if;

  if v_denial_reason is null then
    perform public.ensure_monetization_wallet(p_user_id);
    select * into v_wallet
    from public.monetization_wallets
    where user_id = p_user_id
    for update;

    if v_wallet.period_ends_at is not null
      and v_wallet.period_ends_at <= now() then
      perform public.reset_monetization_allowance(p_user_id);
      select * into v_wallet
      from public.monetization_wallets
      where user_id = p_user_id
      for update;
    end if;

    if v_wallet.balance < v_credit_amount then
      v_denial_reason := 'insufficient_credits';
    end if;
  end if;

  if v_denial_reason is not null then
    insert into public.ai_usage_requests (
      user_id,
      request_key,
      state,
      credit_amount,
      prompt_hash,
      failure_code,
      settled_at,
      contract_version,
      model_key,
      prompt_version,
      access_tier,
      input_byte_count,
      requested_max_output_tokens,
      approved_max_output_tokens,
      reserved_provider_cost_microusd,
      budget_day_started_at
    ) values (
      p_user_id,
      p_request_key,
      'denied',
      greatest(v_credit_amount, 1),
      p_prompt_hash,
      v_denial_reason,
      now(),
      p_contract_version,
      p_model_key,
      p_prompt_version,
      v_access_tier,
      p_input_bytes,
      p_requested_max_output_tokens,
      nullif(v_approved_max_output_tokens, 0),
      v_reserved_provider_cost_microusd,
      v_day_start
    );

    return jsonb_build_object(
      'allowed', false,
      'duplicate', false,
      'state', 'denied',
      'reason', v_denial_reason,
      'creditAmount', greatest(v_credit_amount, 1),
      'balance', case when v_wallet.user_id is null then null else v_wallet.balance end,
      'contractVersion', p_contract_version,
      'modelKey', p_model_key,
      'promptVersion', p_prompt_version,
      'accessTier', v_access_tier,
      'approvedMaxOutputTokens', nullif(v_approved_max_output_tokens, 0),
      'reservedProviderCostMicrousd', v_reserved_provider_cost_microusd
    );
  end if;

  v_bonus_used := least(v_wallet.bonus_balance, v_credit_amount);
  v_allowance_used := v_credit_amount - v_bonus_used;

  update public.monetization_wallets as wallet
  set bonus_balance = wallet.bonus_balance - v_bonus_used,
      allowance_remaining = greatest(
        wallet.allowance_remaining - v_allowance_used,
        0
      ),
      balance = wallet.balance - v_credit_amount,
      lifetime_spent = wallet.lifetime_spent + v_credit_amount,
      updated_at = now()
  where wallet.user_id = p_user_id
  returning * into v_wallet;

  update public.ai_usage_budget_windows
  set reserved_credit_units = reserved_credit_units + v_credit_amount,
      reserved_provider_cost_microusd =
        reserved_provider_cost_microusd + v_reserved_provider_cost_microusd,
      updated_at = now()
  where window_kind = 'day'
    and window_started_at = v_day_start
    and (
      (scope_kind = 'global' and scope_key = 'all')
      or (scope_kind = 'user' and scope_key = p_user_id::text)
    );

  insert into public.ai_usage_requests (
    user_id,
    request_key,
    state,
    credit_amount,
    bonus_used,
    allowance_used,
    prompt_hash,
    contract_version,
    model_key,
    prompt_version,
    access_tier,
    input_byte_count,
    requested_max_output_tokens,
    approved_max_output_tokens,
    funding_period_ends_at,
    reserved_provider_cost_microusd,
    budget_day_started_at
  ) values (
    p_user_id,
    p_request_key,
    'reserved',
    v_credit_amount,
    v_bonus_used,
    v_allowance_used,
    p_prompt_hash,
    p_contract_version,
    p_model_key,
    p_prompt_version,
    v_access_tier,
    p_input_bytes,
    p_requested_max_output_tokens,
    v_approved_max_output_tokens,
    v_wallet.period_ends_at,
    v_reserved_provider_cost_microusd,
    v_day_start
  );

  insert into public.monetization_credit_transactions (
    user_id, type, amount, balance_after, source, description, metadata
  ) values (
    p_user_id,
    'spend',
    -v_credit_amount,
    v_wallet.balance,
    'ai_proxy',
    'AI request reserved',
    jsonb_build_object(
      'request_key', p_request_key,
      'contract_version', p_contract_version,
      'model_key', p_model_key,
      'prompt_version', p_prompt_version
    )
  );

  return jsonb_build_object(
    'allowed', true,
    'duplicate', false,
    'state', 'reserved',
    'creditAmount', v_credit_amount,
    'balance', v_wallet.balance,
    'contractVersion', p_contract_version,
    'modelKey', p_model_key,
    'promptVersion', p_prompt_version,
    'accessTier', v_access_tier,
    'approvedMaxOutputTokens', v_approved_max_output_tokens,
    'reservedProviderCostMicrousd', v_reserved_provider_cost_microusd
  );
end;
$$;
create or replace function public.get_ai_credit_balance_v2(
  p_user_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  c_contract_version constant text := 'ai-proxy-v2';
  v_wallet public.monetization_wallets;
  v_active_plan text;
  v_access_tier text;
begin
  if p_user_id is null then
    raise exception 'invalid AI balance request';
  end if;

  perform public.ensure_monetization_wallet(p_user_id);
  select * into v_wallet
  from public.monetization_wallets
  where user_id = p_user_id
  for update;

  if v_wallet.period_ends_at is not null
    and v_wallet.period_ends_at <= now() then
    perform public.reset_monetization_allowance(p_user_id);
    select * into v_wallet
    from public.monetization_wallets
    where user_id = p_user_id
    for update;
  end if;

  select subscription.plan_id into v_active_plan
  from public.monetization_subscription_statuses as subscription
  where subscription.user_id = p_user_id
    and subscription.is_active = true
    and (
      subscription.expires_at is null
      or subscription.expires_at > now()
    )
  order by subscription.updated_at desc
  limit 1;

  if v_active_plan is null then
    v_access_tier := 'free';
  elsif v_active_plan in ('premium_monthly', 'premium_yearly', 'lifetime') then
    v_access_tier := v_active_plan;
  else
    v_access_tier := 'denied';
  end if;

  return jsonb_build_object(
    'contractVersion', c_contract_version,
    'balance', greatest(v_wallet.balance, 0),
    'allowanceRemaining', greatest(v_wallet.allowance_remaining, 0),
    'bonusBalance', greatest(v_wallet.bonus_balance, 0),
    'accessTier', v_access_tier,
    'periodEndsAt', v_wallet.period_ends_at
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
  p_contract_version text default 'ai-proxy-v2'
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  c_contract_version constant text := 'ai-proxy-v2';
  c_input_cost_per_token_microusd constant bigint := 3;
  c_output_cost_per_token_microusd constant bigint := 15;
  v_usage public.ai_usage_requests;
  v_wallet public.monetization_wallets;
  v_accounted_provider_cost_microusd bigint;
  v_same_funding_period boolean;
  v_restored_bonus integer;
  v_restored_allowance integer;
  v_restored_credits integer;
begin
  if p_user_id is null
    or p_request_key !~ '^[A-Za-z0-9._:-]{8,128}$'
    or p_succeeded is null
    or p_contract_version <> c_contract_version
    or p_input_tokens is not null
      and p_input_tokens not between 0 and 100000
    or p_output_tokens is not null
      and p_output_tokens not between 0 and 4096
    or pg_catalog.octet_length(
      pg_catalog.convert_to(coalesce(p_response_payload, '{}'::jsonb)::text, 'UTF8')
    ) > 65536 then
    raise exception 'invalid AI settlement request';
  end if;

  if p_succeeded and (p_input_tokens is null or p_output_tokens is null) then
    raise exception 'successful AI settlement requires provider token usage';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'chronospark:ai-request:' || p_user_id::text || ':' || p_request_key,
      0
    )
  );

  select * into v_usage
  from public.ai_usage_requests
  where user_id = p_user_id and request_key = p_request_key
  for update;

  if not found then
    raise exception 'AI reservation not found';
  end if;
  if v_usage.contract_version is distinct from p_contract_version then
    raise exception 'AI settlement contract mismatch';
  end if;
  if v_usage.state <> 'reserved' then
    return jsonb_build_object(
      'state', v_usage.state,
      'duplicate', true,
      'refunded', v_usage.state = 'refunded',
      'accountedProviderCostMicrousd',
        v_usage.accounted_provider_cost_microusd
    );
  end if;
  if p_output_tokens is not null
    and p_output_tokens > v_usage.approved_max_output_tokens then
    raise exception 'AI settlement output exceeds approved token cap';
  end if;

  -- Known token usage is priced from the pinned server policy. Unknown timeout,
  -- unhandled, or stale outcomes retain the full reservation conservatively.
  if p_input_tokens is not null or p_output_tokens is not null then
    v_accounted_provider_cost_microusd :=
      greatest(coalesce(p_input_tokens, 0), 0)::bigint
        * c_input_cost_per_token_microusd
      + greatest(coalesce(p_output_tokens, 0), 0)::bigint
        * c_output_cost_per_token_microusd;
  elsif coalesce(p_failure_code, '') = 'invalid_admission_response' then
    -- The Edge handler detects this before any provider request. Product
    -- credits are refunded and the unused provider reservation is released.
    v_accounted_provider_cost_microusd := 0;
  elsif coalesce(p_failure_code, '') in (
    'upstream_timeout',
    'unhandled_proxy_failure',
    'reservation_timeout',
    'invalid_provider_response',
    'provider_response_too_large',
    'invalid_provider_usage'
  ) then
    v_accounted_provider_cost_microusd :=
      coalesce(v_usage.reserved_provider_cost_microusd, 0);
  else
    v_accounted_provider_cost_microusd := 0;
  end if;

  if v_usage.budget_day_started_at is not null then
    perform 1
    from public.ai_usage_budget_windows
    where window_kind = 'day'
      and window_started_at = v_usage.budget_day_started_at
      and (
        (scope_kind = 'global' and scope_key = 'all')
        or (scope_kind = 'user' and scope_key = p_user_id::text)
      )
    order by scope_kind, scope_key, window_kind, window_started_at
    for update;

    update public.ai_usage_budget_windows
    set reserved_credit_units = greatest(
          reserved_credit_units - v_usage.credit_amount,
          0
        ),
        settled_credit_units = settled_credit_units
          + case when p_succeeded then v_usage.credit_amount else 0 end,
        reserved_provider_cost_microusd = greatest(
          reserved_provider_cost_microusd
            - coalesce(v_usage.reserved_provider_cost_microusd, 0),
          0
        ),
        accounted_provider_cost_microusd =
          accounted_provider_cost_microusd
            + v_accounted_provider_cost_microusd,
        updated_at = now()
    where window_kind = 'day'
      and window_started_at = v_usage.budget_day_started_at
      and (
        (scope_kind = 'global' and scope_key = 'all')
        or (scope_kind = 'user' and scope_key = p_user_id::text)
      );
  end if;

  if p_succeeded then
    update public.ai_usage_requests
    set state = 'completed',
        input_tokens = p_input_tokens,
        output_tokens = p_output_tokens,
        provider_request_id = left(p_provider_request_id, 200),
        response_payload = coalesce(p_response_payload, '{}'::jsonb),
        accounted_provider_cost_microusd =
          v_accounted_provider_cost_microusd,
        settled_at = now()
    where id = v_usage.id;

    return jsonb_build_object(
      'state', 'completed',
      'duplicate', false,
      'refunded', false,
      'accountedProviderCostMicrousd',
        v_accounted_provider_cost_microusd
    );
  end if;

  select * into v_wallet
  from public.monetization_wallets
  where user_id = p_user_id
  for update;

  if not found then
    raise exception 'AI reservation wallet not found';
  end if;

  -- Allowance belongs to the exact period that funded the request and does not
  -- carry into a renewed period. Non-expiring bonus credits are always restored.
  v_same_funding_period :=
    v_wallet.period_ends_at is not distinct from v_usage.funding_period_ends_at;
  v_restored_bonus := v_usage.bonus_used;
  v_restored_allowance := case
    when v_same_funding_period then v_usage.allowance_used
    else 0
  end;
  v_restored_credits := v_restored_bonus + v_restored_allowance;

  update public.monetization_wallets as wallet
  set bonus_balance = wallet.bonus_balance + v_restored_bonus,
      allowance_remaining =
        wallet.allowance_remaining + v_restored_allowance,
      balance = wallet.balance + v_restored_credits,
      lifetime_spent = greatest(
        wallet.lifetime_spent - v_usage.credit_amount,
        0
      ),
      updated_at = now()
  where wallet.user_id = p_user_id
  returning * into v_wallet;

  update public.ai_usage_requests
  set state = 'refunded',
      input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
      output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
      provider_request_id = left(p_provider_request_id, 200),
      failure_code = left(coalesce(p_failure_code, 'provider_failure'), 100),
      accounted_provider_cost_microusd =
        v_accounted_provider_cost_microusd,
      settled_at = now()
  where id = v_usage.id;

  insert into public.monetization_credit_transactions (
    user_id, type, amount, balance_after, source, description, metadata
  ) values (
    p_user_id,
    'refund',
    v_restored_credits,
    v_wallet.balance,
    'ai_proxy',
    'AI request reservation refunded',
    jsonb_build_object(
      'request_key', p_request_key,
      'failure_code', p_failure_code,
      'contract_version', p_contract_version,
      'reserved_credit_amount', v_usage.credit_amount,
      'restored_credit_amount', v_restored_credits,
      'expired_allowance_not_restored',
        v_usage.allowance_used - v_restored_allowance,
      'funding_period_ends_at', v_usage.funding_period_ends_at,
      'settlement_period_ends_at', v_wallet.period_ends_at
    )
  );

  return jsonb_build_object(
    'state', 'refunded',
    'duplicate', false,
    'refunded', true,
    'balance', v_wallet.balance,
    'restoredCreditAmount', v_restored_credits,
    'expiredAllowanceNotRestored',
      v_usage.allowance_used - v_restored_allowance,
    'accountedProviderCostMicrousd',
      v_accounted_provider_cost_microusd
  );
end;
$$;
-- Compatibility settlement for old deployed Edge code and legacy rows. Any v2
-- row is routed through the v2 authority so output, budget, and refund policy
-- cannot be bypassed through the old function signature.
create or replace function public.settle_ai_usage(
  p_user_id uuid,
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
  v_contract_version text;
  v_usage public.ai_usage_requests;
  v_wallet public.monetization_wallets;
begin
  select usage.contract_version into v_contract_version
  from public.ai_usage_requests as usage
  where usage.user_id = p_user_id and usage.request_key = p_request_key;

  if not found then
    raise exception 'AI reservation not found';
  end if;

  if v_contract_version = 'ai-proxy-v2' then
    return public.settle_ai_usage_v2(
      p_user_id,
      p_request_key,
      p_succeeded,
      p_input_tokens,
      p_output_tokens,
      p_provider_request_id,
      p_failure_code,
      p_response_payload,
      'ai-proxy-v2'
    );
  end if;

  select * into v_usage
  from public.ai_usage_requests
  where user_id = p_user_id and request_key = p_request_key
  for update;

  if v_usage.state <> 'reserved' then
    return jsonb_build_object('state', v_usage.state, 'duplicate', true);
  end if;

  if p_succeeded then
    update public.ai_usage_requests
    set state = 'completed',
        input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
        output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
        provider_request_id = left(p_provider_request_id, 200),
        response_payload = coalesce(p_response_payload, '{}'::jsonb),
        settled_at = now()
    where id = v_usage.id;
    return jsonb_build_object('state', 'completed', 'refunded', false);
  end if;

  select * into v_wallet
  from public.monetization_wallets
  where user_id = p_user_id
  for update;

  update public.monetization_wallets
  set bonus_balance = bonus_balance + v_usage.bonus_used,
      allowance_remaining = allowance_remaining + v_usage.allowance_used,
      balance = balance + v_usage.credit_amount,
      lifetime_spent = greatest(lifetime_spent - v_usage.credit_amount, 0),
      updated_at = now()
  where user_id = p_user_id
  returning * into v_wallet;

  update public.ai_usage_requests
  set state = 'refunded',
      input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
      output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
      provider_request_id = left(p_provider_request_id, 200),
      failure_code = left(coalesce(p_failure_code, 'provider_failure'), 100),
      settled_at = now()
  where id = v_usage.id;

  insert into public.monetization_credit_transactions (
    user_id, type, amount, balance_after, source, description, metadata
  ) values (
    p_user_id,
    'refund',
    v_usage.credit_amount,
    v_wallet.balance,
    'ai_proxy',
    'Legacy AI request reservation refunded',
    jsonb_build_object(
      'request_key', p_request_key,
      'failure_code', p_failure_code,
      'contract_version', v_contract_version
    )
  );

  return jsonb_build_object(
    'state', 'refunded', 'refunded', true, 'balance', v_wallet.balance
  );
end;
$$;
create or replace function public.refund_stale_ai_usage_reservations(
  p_older_than interval default interval '10 minutes'
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_usage public.ai_usage_requests;
  v_result jsonb;
  v_count integer := 0;
begin
  if p_older_than < interval '1 minute' then
    raise exception 'stale reservation age must be at least one minute';
  end if;

  for v_usage in
    select * from public.ai_usage_requests
    where state = 'reserved' and created_at < now() - p_older_than
    order by created_at
  loop
    if v_usage.contract_version = 'ai-proxy-v2' then
      v_result := public.settle_ai_usage_v2(
        v_usage.user_id,
        v_usage.request_key,
        false,
        null,
        null,
        null,
        'reservation_timeout',
        '{}'::jsonb,
        'ai-proxy-v2'
      );
    else
      v_result := public.settle_ai_usage(
        v_usage.user_id,
        v_usage.request_key,
        false,
        null,
        null,
        null,
        'reservation_timeout',
        '{}'::jsonb
      );
    end if;
    if v_result ->> 'state' = 'refunded'
      and coalesce((v_result ->> 'duplicate')::boolean, false) = false then
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.admit_ai_usage_v2(
  uuid, text, text, text, text, text, integer, integer
) from public, anon, authenticated, service_role;
revoke all on function public.get_ai_credit_balance_v2(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.settle_ai_usage_v2(
  uuid, text, boolean, integer, integer, text, text, jsonb, text
) from public, anon, authenticated, service_role;
revoke all on function public.refund_stale_ai_usage_reservations(interval)
  from public, anon, authenticated, service_role;
-- Deployment compatibility gate: the currently deployed Edge function may use
-- these legacy functions until the v2 Edge deployment is live. Client roles
-- remain denied. Revoking service_role from the legacy functions is a separate,
-- post-cutover operational cleanup after old-call telemetry reaches zero.
revoke all on function public.reserve_ai_usage(uuid, text, integer, text)
  from public, anon, authenticated;
revoke all on function public.settle_ai_usage(
  uuid, text, boolean, integer, integer, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.reserve_ai_usage(uuid, text, integer, text)
  to service_role;
grant execute on function public.settle_ai_usage(
  uuid, text, boolean, integer, integer, text, text, jsonb
) to service_role;
grant execute on function public.admit_ai_usage_v2(
  uuid, text, text, text, text, text, integer, integer
) to service_role;
grant execute on function public.get_ai_credit_balance_v2(uuid)
  to service_role;
grant execute on function public.settle_ai_usage_v2(
  uuid, text, boolean, integer, integer, text, text, jsonb, text
) to service_role;
grant execute on function public.refund_stale_ai_usage_reservations(interval)
  to service_role;
