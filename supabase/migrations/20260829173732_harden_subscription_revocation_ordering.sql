-- Preserve Google Play event ordering at the subscription authority boundary.
-- Existing RPC signatures remain as compatibility wrappers for verify-receipt.

alter table public.monetization_subscription_statuses
  add column if not exists provider_event_time timestamptz;

update public.monetization_subscription_statuses
set provider_event_time = updated_at
where provider_event_time is null;

alter table public.monetization_subscription_statuses
  alter column provider_event_time set default now(),
  alter column provider_event_time set not null;

alter table public.purchase_bindings
  add column if not exists predecessor_token_hash text;

alter table public.purchase_bindings
  drop constraint if exists purchase_bindings_predecessor_token_hash_check;

alter table public.purchase_bindings
  add constraint purchase_bindings_predecessor_token_hash_check
  check (
    predecessor_token_hash is null
    or (
      predecessor_token_hash ~ '^[0-9a-f]{64}$'
      and predecessor_token_hash <> token_hash
    )
  );

create index if not exists purchase_bindings_predecessor_idx
  on public.purchase_bindings (predecessor_token_hash)
  where predecessor_token_hash is not null;

create or replace function public.protect_purchase_binding_lineage()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.predecessor_token_hash is not null
    and new.predecessor_token_hash is distinct from old.predecessor_token_hash then
    raise exception 'purchase binding lineage is immutable';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_purchase_binding_lineage
  on public.purchase_bindings;
create trigger protect_purchase_binding_lineage
before update of predecessor_token_hash on public.purchase_bindings
for each row execute function public.protect_purchase_binding_lineage();

create or replace function public.bind_verified_purchase_token(
  p_purchase_token_hash text,
  p_user_id uuid,
  p_product_id text,
  p_bound_at timestamptz,
  p_predecessor_token_hash text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_predecessor public.purchase_bindings;
  v_inserted boolean := false;
begin
  if p_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or p_user_id is null
    or p_product_id not in (
      'chronospark_premium_monthly', 'chronospark_premium_annual'
    )
    or p_bound_at is null
    or (
      p_predecessor_token_hash is not null
      and (
        p_predecessor_token_hash !~ '^[0-9a-f]{64}$'
        or p_predecessor_token_hash = p_purchase_token_hash
      )
    ) then
    raise exception 'invalid purchase binding';
  end if;

  -- Related token hashes must serialize even when the predecessor row has not
  -- been created yet. Lock in lexical order so concurrent replacement and
  -- predecessor verification cannot split one Play lineage across accounts.
  if p_predecessor_token_hash is null
    or p_purchase_token_hash < p_predecessor_token_hash then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_purchase_token_hash, 0)
    );
    if p_predecessor_token_hash is not null then
      perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_predecessor_token_hash, 0)
      );
    end if;
  else
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_predecessor_token_hash, 0)
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_purchase_token_hash, 0)
    );
  end if;

  if exists (
    select 1
    from public.purchase_bindings
    where predecessor_token_hash = p_purchase_token_hash
      and user_id <> p_user_id
  ) then
    return jsonb_build_object(
      'bound', false, 'reason', 'lineage_user_mismatch'
    );
  end if;

  if p_predecessor_token_hash is not null then
    select * into v_predecessor
    from public.purchase_bindings
    where token_hash = p_predecessor_token_hash
    for update;
    if found and v_predecessor.user_id <> p_user_id then
      return jsonb_build_object(
        'bound', false, 'reason', 'predecessor_user_mismatch'
      );
    end if;

    if exists (
      with recursive ancestry(token_hash, path) as (
        select p_predecessor_token_hash, array[p_predecessor_token_hash]
        union all
        select binding.predecessor_token_hash,
          ancestry.path || binding.predecessor_token_hash
        from ancestry
        join public.purchase_bindings binding
          on binding.token_hash = ancestry.token_hash
        where binding.predecessor_token_hash is not null
          and not binding.predecessor_token_hash = any(ancestry.path)
      )
      select 1 from ancestry where token_hash = p_purchase_token_hash
    ) then
      return jsonb_build_object('bound', false, 'reason', 'lineage_cycle');
    end if;
  end if;

  insert into public.purchase_bindings (
    token_hash, user_id, product_id, created_at, predecessor_token_hash
  ) values (
    p_purchase_token_hash, p_user_id, p_product_id, p_bound_at,
    p_predecessor_token_hash
  ) on conflict (token_hash) do nothing
  returning true into v_inserted;

  select * into v_binding
  from public.purchase_bindings
  where token_hash = p_purchase_token_hash
  for update;

  if v_binding.user_id <> p_user_id or v_binding.product_id <> p_product_id then
    return jsonb_build_object('bound', false, 'reason', 'binding_mismatch');
  end if;

  if p_predecessor_token_hash is not null then
    if v_binding.predecessor_token_hash is null then
      update public.purchase_bindings
      set predecessor_token_hash = p_predecessor_token_hash
      where token_hash = p_purchase_token_hash
      returning * into v_binding;
    elsif v_binding.predecessor_token_hash <> p_predecessor_token_hash then
      return jsonb_build_object('bound', false, 'reason', 'lineage_mismatch');
    end if;
  end if;

  return jsonb_build_object(
    'bound', true,
    'duplicate', not coalesce(v_inserted, false),
    'predecessorTokenHash', v_binding.predecessor_token_hash
  );
end;
$$;

create or replace function public.bind_verified_purchase_token(
  p_purchase_token_hash text,
  p_user_id uuid,
  p_product_id text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
begin
  return public.bind_verified_purchase_token(
    p_purchase_token_hash, p_user_id, p_product_id, now(), null
  );
end;
$$;

alter table public.google_play_rtdn_events
  add column if not exists claimed_at timestamptz;

alter table public.google_play_rtdn_events
  drop constraint if exists google_play_rtdn_events_state_check;

alter table public.google_play_rtdn_events
  add constraint google_play_rtdn_events_state_check
  check (state in ('received', 'processing', 'processed', 'ignored', 'failed'));

create or replace function public.claim_google_play_rtdn_event(
  p_message_id text,
  p_package_name text,
  p_event_time timestamptz,
  p_event_type text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_event public.google_play_rtdn_events;
begin
  if nullif(btrim(p_message_id), '') is null or length(p_message_id) > 200
    or nullif(btrim(p_package_name), '') is null
    or p_event_time is null
    or nullif(btrim(p_event_type), '') is null then
    raise exception 'invalid RTDN claim';
  end if;

  insert into public.google_play_rtdn_events (
    message_id, package_name, event_time, event_type, payload, state, claimed_at
  ) values (
    p_message_id, p_package_name, p_event_time, p_event_type,
    coalesce(p_payload, '{}'::jsonb), 'processing', now()
  ) on conflict (message_id) do nothing
  returning * into v_event;

  if found then
    return jsonb_build_object(
      'claimed', true, 'completed', false, 'state', v_event.state
    );
  end if;

  select * into v_event
  from public.google_play_rtdn_events
  where message_id = p_message_id
  for update;

  if v_event.state in ('processed', 'ignored') then
    return jsonb_build_object(
      'claimed', false, 'completed', true, 'state', v_event.state
    );
  end if;

  if v_event.state = 'processing'
    and v_event.claimed_at is not null
    and v_event.claimed_at > now() - interval '5 minutes' then
    return jsonb_build_object(
      'claimed', false, 'completed', false, 'retry', true,
      'state', v_event.state
    );
  end if;

  update public.google_play_rtdn_events
  set package_name = p_package_name,
    event_time = p_event_time,
    event_type = p_event_type,
    payload = coalesce(p_payload, '{}'::jsonb),
    state = 'processing',
    failure_code = null,
    processed_at = null,
    claimed_at = now()
  where message_id = p_message_id
  returning * into v_event;

  return jsonb_build_object(
    'claimed', true, 'completed', false, 'state', v_event.state
  );
end;
$$;

create or replace function public.reconcile_google_play_subscription(
  p_purchase_token_hash text,
  p_product_id text,
  p_status text,
  p_is_active boolean,
  p_auto_renews boolean,
  p_order_id text,
  p_expires_at timestamptz,
  p_provider_event_time timestamptz,
  p_event_key text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_current_binding public.purchase_bindings;
  v_current public.monetization_subscription_statuses;
  v_purchase public.monetization_purchases;
  v_plan_id text;
  v_period_credits integer;
  v_renewed boolean := false;
  v_wallet public.monetization_wallets;
  v_payload jsonb;
  v_event_count integer;
  v_incoming_is_predecessor boolean := false;
  v_current_is_predecessor boolean := false;
begin
  if p_status not in ('pending', 'active', 'grace', 'on_hold', 'paused',
    'canceled', 'expired', 'revoked') then
    raise exception 'unsupported status';
  end if;
  if p_provider_event_time is null then
    raise exception 'provider event time is required';
  end if;

  select * into v_binding
  from public.purchase_bindings
  where token_hash = p_purchase_token_hash
  for update;
  if not found or v_binding.product_id <> p_product_id then
    return jsonb_build_object('applied', false, 'reason', 'binding_not_found');
  end if;

  v_plan_id := case p_product_id
    when 'chronospark_premium_monthly' then 'premium_monthly'
    when 'chronospark_premium_annual' then 'premium_yearly'
    else null
  end;
  v_period_credits := case v_plan_id
    when 'premium_monthly' then 300
    when 'premium_yearly' then 360
    else 0
  end;
  if v_plan_id is null then
    return jsonb_build_object('applied', false, 'reason', 'unsupported_product');
  end if;

  v_payload := coalesce(p_payload, '{}'::jsonb) || jsonb_build_object(
    'providerEventTime', p_provider_event_time
  );

  select * into v_current
  from public.monetization_subscription_statuses
  where user_id = v_binding.user_id
  for update;

  if v_current.user_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash then
    select * into v_current_binding
    from public.purchase_bindings
    where token_hash = v_current.purchase_token_hash;

    with recursive current_ancestry(token_hash, path) as (
      select v_current.purchase_token_hash,
        array[v_current.purchase_token_hash]
      union all
      select binding.predecessor_token_hash,
        current_ancestry.path || binding.predecessor_token_hash
      from current_ancestry
      join public.purchase_bindings binding
        on binding.token_hash = current_ancestry.token_hash
      where binding.predecessor_token_hash is not null
        and not binding.predecessor_token_hash = any(current_ancestry.path)
    )
    select exists (
      select 1 from current_ancestry
      where token_hash = p_purchase_token_hash
    ) into v_incoming_is_predecessor;

    with recursive incoming_ancestry(token_hash, path) as (
      select p_purchase_token_hash, array[p_purchase_token_hash]
      union all
      select binding.predecessor_token_hash,
        incoming_ancestry.path || binding.predecessor_token_hash
      from incoming_ancestry
      join public.purchase_bindings binding
        on binding.token_hash = incoming_ancestry.token_hash
      where binding.predecessor_token_hash is not null
        and not binding.predecessor_token_hash = any(incoming_ancestry.path)
    )
    select exists (
      select 1 from incoming_ancestry
      where token_hash = v_current.purchase_token_hash
    ) into v_current_is_predecessor;
  end if;

  select * into v_purchase
  from public.monetization_purchases
  where purchase_token_hash = p_purchase_token_hash
  for update;

  if v_current.user_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash
    and (
      not p_is_active
      or v_current_binding.token_hash is null
      or v_incoming_is_predecessor
      or (
        not v_current_is_predecessor
        and v_binding.created_at <= v_current_binding.created_at
      )
    ) then
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, expires_at, metadata
    ) values (
      v_binding.user_id, p_event_key,
      'subscription_' || p_status || '_old_token',
      v_plan_id, p_product_id, p_is_active, p_provider_event_time,
      p_expires_at, v_payload
    ) on conflict (event_key) do nothing;

    insert into public.monetization_purchases (
      user_id, product_id, purchase_type, purchase_state,
      purchase_token_hash, order_id, subscription_plan_id, payload, verified_at
    ) values (
      v_binding.user_id, p_product_id, 'subscription', p_status,
      p_purchase_token_hash, p_order_id, v_plan_id, v_payload, now()
    ) on conflict (purchase_token_hash) do update set
      purchase_state = case
        when public.monetization_purchases.purchase_state = 'refunded'
          then public.monetization_purchases.purchase_state
        else excluded.purchase_state
      end,
      order_id = coalesce(excluded.order_id, public.monetization_purchases.order_id),
      payload = public.monetization_purchases.payload || excluded.payload,
      verified_at = now();

    return jsonb_build_object(
      'applied', false, 'handled', true, 'reason', 'old_token',
      'userId', v_binding.user_id, 'active', v_current.is_active
    );
  end if;

  if v_current.user_id is not null
    and v_current.purchase_token_hash is not distinct from p_purchase_token_hash
    and p_is_active
    and (
      v_current.status = 'revoked'
      or v_purchase.purchase_state = 'refunded'
    ) then
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, expires_at, metadata
    ) values (
      v_binding.user_id, p_event_key, 'subscription_terminal_token_ignored',
      v_plan_id, p_product_id, false, p_provider_event_time,
      p_expires_at, v_payload
    ) on conflict (event_key) do nothing;
    return jsonb_build_object(
      'applied', false, 'handled', true, 'reason', 'terminal_token',
      'userId', v_binding.user_id, 'active', false
    );
  end if;

  if v_current.user_id is not null
    and (
      v_current.provider_event_time > p_provider_event_time
      or (
        v_current.provider_event_time = p_provider_event_time
        and not v_current.is_active
        and p_is_active
        and not (
          p_expires_at is not null
          and v_current.expires_at is not null
          and p_expires_at > v_current.expires_at
        )
      )
    ) then
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, expires_at, metadata
    ) values (
      v_binding.user_id, p_event_key, 'subscription_stale_ignored',
      v_plan_id, p_product_id, p_is_active, p_provider_event_time,
      p_expires_at, v_payload
    ) on conflict (event_key) do nothing;
    return jsonb_build_object(
      'applied', false, 'handled', true, 'stale', true,
      'reason', 'stale_event', 'userId', v_binding.user_id
    );
  end if;

  if p_event_key is not null and exists (
    select 1
    from public.monetization_entitlement_events
    where event_key = p_event_key
  ) then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_binding.user_id
    );
  end if;

  v_renewed := p_is_active and p_expires_at is not null and
    (v_current.expires_at is null or p_expires_at > v_current.expires_at);

  insert into public.monetization_entitlement_events (
    user_id, event_key, event_type, plan_id, product_id, is_active,
    effective_at, expires_at, metadata
  ) values (
    v_binding.user_id, p_event_key,
    case when v_renewed then 'subscription_renewed'
      else 'subscription_' || p_status end,
    v_plan_id, p_product_id, p_is_active, p_provider_event_time,
    p_expires_at, v_payload
  ) on conflict (event_key) do nothing;
  get diagnostics v_event_count = row_count;
  if p_event_key is not null and v_event_count = 0 then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_binding.user_id
    );
  end if;

  insert into public.monetization_subscription_statuses (
    user_id, plan_id, product_id, status, is_active, auto_renews,
    period_credits, started_at, expires_at, order_id,
    purchase_token_hash, provider_event_time, metadata, updated_at
  ) values (
    v_binding.user_id, v_plan_id, p_product_id, p_status, p_is_active,
    p_auto_renews, v_period_credits, coalesce(v_current.started_at, now()),
    p_expires_at, p_order_id, p_purchase_token_hash, p_provider_event_time,
    v_payload, now()
  ) on conflict (user_id) do update set
    plan_id = excluded.plan_id,
    product_id = excluded.product_id,
    status = excluded.status,
    is_active = excluded.is_active,
    auto_renews = excluded.auto_renews,
    period_credits = excluded.period_credits,
    started_at = coalesce(
      public.monetization_subscription_statuses.started_at,
      excluded.started_at
    ),
    expires_at = excluded.expires_at,
    order_id = excluded.order_id,
    purchase_token_hash = excluded.purchase_token_hash,
    provider_event_time = excluded.provider_event_time,
    metadata = excluded.metadata,
    updated_at = now();

  insert into public.monetization_purchases (
    user_id, product_id, purchase_type, purchase_state, purchase_token_hash,
    order_id, subscription_plan_id, payload, verified_at
  ) values (
    v_binding.user_id, p_product_id, 'subscription', p_status,
    p_purchase_token_hash, p_order_id, v_plan_id, v_payload, now()
  ) on conflict (purchase_token_hash) do update set
    purchase_state = excluded.purchase_state,
    order_id = coalesce(excluded.order_id, public.monetization_purchases.order_id),
    payload = public.monetization_purchases.payload || excluded.payload,
    verified_at = now();

  v_wallet := public.reset_monetization_allowance(v_binding.user_id);
  return jsonb_build_object(
    'applied', true, 'handled', true, 'userId', v_binding.user_id,
    'planId', v_plan_id,
    'eventType', case when v_renewed then 'subscription_renewed'
      else 'subscription_' || p_status end,
    'creditsGranted', 0, 'remainingCredits', v_wallet.balance,
    'active', p_is_active, 'renewed', v_renewed
  );
end;
$$;

create or replace function public.reconcile_google_play_subscription(
  p_purchase_token_hash text,
  p_product_id text,
  p_status text,
  p_is_active boolean,
  p_auto_renews boolean,
  p_order_id text,
  p_expires_at timestamptz,
  p_event_key text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
begin
  return public.reconcile_google_play_subscription(
    p_purchase_token_hash, p_product_id, p_status, p_is_active,
    p_auto_renews, p_order_id, p_expires_at, now(), p_event_key,
    coalesce(p_payload, '{}'::jsonb)
  );
end;
$$;

create or replace function public.reconcile_google_play_voided_purchase(
  p_purchase_token_hash text,
  p_provider_event_time timestamptz,
  p_event_key text,
  p_order_id text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_purchase public.monetization_purchases;
  v_current public.monetization_subscription_statuses;
  v_wallet public.monetization_wallets;
  v_payload jsonb;
  v_event_count integer;
begin
  if p_provider_event_time is null then
    raise exception 'provider event time is required';
  end if;

  select * into v_binding
  from public.purchase_bindings
  where token_hash = p_purchase_token_hash
  for update;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'binding_not_found');
  end if;

  if p_event_key is not null and exists (
    select 1
    from public.monetization_entitlement_events
    where event_key = p_event_key
  ) then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_binding.user_id
    );
  end if;

  select * into v_purchase
  from public.monetization_purchases
  where purchase_token_hash = p_purchase_token_hash
  for update;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'purchase_not_found');
  end if;

  select * into v_current
  from public.monetization_subscription_statuses
  where user_id = v_binding.user_id
  for update;

  v_payload := coalesce(p_payload, '{}'::jsonb) || jsonb_build_object(
    'providerEventTime', p_provider_event_time
  );

  if v_current.user_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash then
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, metadata
    ) values (
      v_binding.user_id, p_event_key, 'purchase_refunded_old_token',
      v_purchase.subscription_plan_id, v_purchase.product_id, false,
      p_provider_event_time, v_payload
    ) on conflict (event_key) do nothing;
    get diagnostics v_event_count = row_count;
    if p_event_key is not null and v_event_count = 0 then
      return jsonb_build_object(
        'applied', false, 'duplicate', true, 'handled', true,
        'userId', v_binding.user_id
      );
    end if;

    update public.monetization_purchases
    set purchase_state = 'refunded',
      order_id = coalesce(p_order_id, order_id),
      payload = payload || v_payload,
      verified_at = now()
    where id = v_purchase.id;

    return jsonb_build_object(
      'applied', false, 'handled', true, 'reason', 'old_token',
      'userId', v_binding.user_id, 'productId', v_purchase.product_id,
      'currentPreserved', true
    );
  end if;

  if v_current.user_id is not null
    and v_current.provider_event_time > p_provider_event_time then
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, metadata
    ) values (
      v_binding.user_id, p_event_key, 'purchase_refund_stale_ignored',
      v_purchase.subscription_plan_id, v_purchase.product_id, false,
      p_provider_event_time, v_payload
    ) on conflict (event_key) do nothing;
    get diagnostics v_event_count = row_count;
    if p_event_key is not null and v_event_count = 0 then
      return jsonb_build_object(
        'applied', false, 'duplicate', true, 'handled', true,
        'userId', v_binding.user_id
      );
    end if;
    return jsonb_build_object(
      'applied', false, 'handled', true, 'stale', true,
      'reason', 'stale_event', 'userId', v_binding.user_id
    );
  end if;

  insert into public.monetization_entitlement_events (
    user_id, event_key, event_type, plan_id, product_id, is_active,
    effective_at, metadata
  ) values (
    v_binding.user_id, p_event_key, 'purchase_refunded',
    v_purchase.subscription_plan_id, v_purchase.product_id, false,
    p_provider_event_time, v_payload
  ) on conflict (event_key) do nothing;
  get diagnostics v_event_count = row_count;
  if p_event_key is not null and v_event_count = 0 then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_binding.user_id
    );
  end if;

  update public.monetization_purchases
  set purchase_state = 'refunded',
    order_id = coalesce(p_order_id, order_id),
    payload = payload || v_payload,
    verified_at = now()
  where id = v_purchase.id;

  update public.monetization_subscription_statuses
  set status = 'revoked',
    is_active = false,
    auto_renews = false,
    provider_event_time = p_provider_event_time,
    metadata = metadata || v_payload,
    updated_at = now()
  where user_id = v_binding.user_id
    and purchase_token_hash = p_purchase_token_hash;

  v_wallet := public.reset_monetization_allowance(v_binding.user_id);
  return jsonb_build_object(
    'applied', true, 'handled', true, 'userId', v_binding.user_id,
    'productId', v_purchase.product_id, 'remainingCredits', v_wallet.balance,
    'active', false
  );
end;
$$;

create or replace function public.reconcile_google_play_voided_purchase(
  p_purchase_token_hash text,
  p_event_key text,
  p_order_id text default null,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
begin
  return public.reconcile_google_play_voided_purchase(
    p_purchase_token_hash, now(), p_event_key, p_order_id,
    coalesce(p_payload, '{}'::jsonb)
  );
end;
$$;

create or replace function public.expire_stale_monetization_subscriptions()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status public.monetization_subscription_statuses;
  v_count integer := 0;
begin
  for v_status in select * from public.monetization_subscription_statuses
    where is_active = true and expires_at is not null and expires_at <= now()
    for update skip locked
  loop
    update public.monetization_subscription_statuses
    set status = 'expired',
      is_active = false,
      auto_renews = false,
      updated_at = now()
    where user_id = v_status.user_id;
    perform public.reset_monetization_allowance(v_status.user_id);
    insert into public.monetization_entitlement_events (
      user_id, event_key, event_type, plan_id, product_id, is_active,
      effective_at, expires_at, metadata
    ) values (
      v_status.user_id,
      'expiry:' || v_status.user_id::text || ':' ||
        extract(epoch from v_status.expires_at)::bigint::text,
      'subscription_expired', v_status.plan_id, v_status.product_id,
      false, now(), v_status.expires_at,
      jsonb_build_object('source', 'expiry_reconciliation')
    ) on conflict (event_key) do nothing;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.claim_google_play_rtdn_event(
  text, text, timestamptz, text, jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.protect_purchase_binding_lineage()
  from public, anon, authenticated, service_role;
revoke all on function public.bind_verified_purchase_token(
  text, uuid, text, timestamptz, text
) from public, anon, authenticated, service_role;
revoke all on function public.reconcile_google_play_subscription(
  text, text, text, boolean, boolean, text, timestamptz, timestamptz,
  text, jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.reconcile_google_play_voided_purchase(
  text, timestamptz, text, text, jsonb
) from public, anon, authenticated, service_role;

grant execute on function public.claim_google_play_rtdn_event(
  text, text, timestamptz, text, jsonb
) to service_role;
grant update (predecessor_token_hash)
  on table public.purchase_bindings to service_role;
grant execute on function public.bind_verified_purchase_token(
  text, uuid, text, timestamptz, text
) to service_role;
grant execute on function public.reconcile_google_play_subscription(
  text, text, text, boolean, boolean, text, timestamptz, timestamptz,
  text, jsonb
) to service_role;
grant execute on function public.reconcile_google_play_voided_purchase(
  text, timestamptz, text, text, jsonb
) to service_role;
