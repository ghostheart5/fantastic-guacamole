-- Durable billing identity, paid-grant causality, and provider recheck safety.

create table public.billing_principals (
  billing_principal_id uuid primary key default gen_random_uuid(),
  current_user_id uuid unique references auth.users(id) on delete set null,
  retired_at timestamptz,
  attached_at timestamptz,
  detached_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint billing_principals_retired_owner_check check (
    retired_at is null or current_user_id is null
  )
);

alter table public.billing_principals enable row level security;

insert into public.billing_principals (
  current_user_id, attached_at
)
select user_id, now()
from (
  select user_id from public.purchase_bindings
  union
  select user_id from public.monetization_subscription_statuses
  union
  select user_id from public.monetization_wallets
  union
  select user_id from public.monetization_credit_transactions
  union
  select user_id from public.monetization_purchases
  union
  select user_id from public.monetization_entitlement_events
  union
  select user_id from public.ai_usage_requests
) existing_users
where user_id is not null
on conflict do nothing;

alter table public.purchase_bindings
  add column billing_principal_id uuid;
alter table public.monetization_subscription_statuses
  add column billing_principal_id uuid;
alter table public.monetization_wallets
  add column billing_principal_id uuid;
alter table public.monetization_credit_transactions
  add column billing_principal_id uuid;
alter table public.monetization_purchases
  add column billing_principal_id uuid;
alter table public.monetization_entitlement_events
  add column billing_principal_id uuid;
alter table public.ai_usage_requests
  add column billing_principal_id uuid;

update public.purchase_bindings binding
set billing_principal_id = principal.billing_principal_id
from public.billing_principals principal
where principal.current_user_id = binding.user_id;
update public.monetization_subscription_statuses status
set billing_principal_id = principal.billing_principal_id
from public.billing_principals principal
where principal.current_user_id = status.user_id;
update public.monetization_wallets wallet
set billing_principal_id = principal.billing_principal_id
from public.billing_principals principal
where principal.current_user_id = wallet.user_id;
update public.monetization_credit_transactions credit_transaction
set billing_principal_id = principal.billing_principal_id
from public.billing_principals principal
where principal.current_user_id = credit_transaction.user_id;
update public.monetization_purchases purchase
set billing_principal_id = principal.billing_principal_id
from public.billing_principals principal
where principal.current_user_id = purchase.user_id;
update public.monetization_entitlement_events entitlement_event
set billing_principal_id = principal.billing_principal_id
from public.billing_principals principal
where principal.current_user_id = entitlement_event.user_id;
update public.ai_usage_requests usage
set billing_principal_id = principal.billing_principal_id
from public.billing_principals principal
where principal.current_user_id = usage.user_id;

alter table public.purchase_bindings
  alter column billing_principal_id set not null,
  drop constraint if exists purchase_bindings_user_id_fkey,
  alter column user_id drop not null,
  add constraint purchase_bindings_billing_principal_id_fkey
    foreign key (billing_principal_id)
    references public.billing_principals(billing_principal_id),
  add constraint purchase_bindings_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete set null;

alter table public.monetization_subscription_statuses
  alter column billing_principal_id set not null,
  drop constraint if exists monetization_subscription_statuses_pkey,
  drop constraint if exists monetization_subscription_statuses_user_id_fkey,
  alter column user_id drop not null,
  add constraint monetization_subscription_statuses_pkey
    primary key (billing_principal_id),
  add constraint monetization_subscription_statuses_user_id_key
    unique (user_id),
  add constraint monetization_subscription_statuses_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete set null,
  add constraint monetization_subscription_statuses_principal_fkey
    foreign key (billing_principal_id)
    references public.billing_principals(billing_principal_id),
  add constraint monetization_subscription_statuses_terminal_inactive_check
    check (
      status not in ('expired', 'revoked')
      or (is_active = false and auto_renews = false)
    );

alter table public.monetization_wallets
  alter column billing_principal_id set not null,
  drop constraint if exists monetization_wallets_pkey,
  drop constraint if exists monetization_wallets_user_id_fkey,
  alter column user_id drop not null,
  add constraint monetization_wallets_pkey primary key (billing_principal_id),
  add constraint monetization_wallets_user_id_key unique (user_id),
  add constraint monetization_wallets_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete set null,
  add constraint monetization_wallets_principal_fkey
    foreign key (billing_principal_id)
    references public.billing_principals(billing_principal_id);

alter table public.monetization_credit_transactions
  alter column billing_principal_id set not null,
  drop constraint if exists monetization_credit_transactions_user_id_fkey,
  alter column user_id drop not null,
  add constraint monetization_credit_transactions_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete set null,
  add constraint monetization_credit_transactions_principal_fkey
    foreign key (billing_principal_id)
    references public.billing_principals(billing_principal_id);

alter table public.monetization_purchases
  alter column billing_principal_id set not null,
  drop constraint if exists monetization_purchases_user_id_fkey,
  alter column user_id drop not null,
  add constraint monetization_purchases_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete set null,
  add constraint monetization_purchases_principal_fkey
    foreign key (billing_principal_id)
    references public.billing_principals(billing_principal_id);

alter table public.monetization_entitlement_events
  alter column billing_principal_id set not null,
  drop constraint if exists monetization_entitlement_events_user_id_fkey,
  alter column user_id drop not null,
  add constraint monetization_entitlement_events_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete set null,
  add constraint monetization_entitlement_events_principal_fkey
    foreign key (billing_principal_id)
    references public.billing_principals(billing_principal_id);

alter table public.ai_usage_requests
  alter column billing_principal_id set not null,
  drop constraint if exists ai_usage_requests_user_id_fkey,
  alter column user_id drop not null,
  add constraint ai_usage_requests_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete set null,
  add constraint ai_usage_requests_principal_fkey
    foreign key (billing_principal_id)
    references public.billing_principals(billing_principal_id),
  add constraint ai_usage_requests_principal_request_key_key
    unique (billing_principal_id, request_key);

create index purchase_bindings_principal_idx
  on public.purchase_bindings (billing_principal_id);
create index monetization_credit_transactions_principal_idx
  on public.monetization_credit_transactions (
    billing_principal_id, created_at desc
  );
create index monetization_purchases_principal_idx
  on public.monetization_purchases (billing_principal_id, created_at desc);
create index monetization_entitlement_events_principal_idx
  on public.monetization_entitlement_events (
    billing_principal_id, created_at desc
  );

create table public.monetization_allowance_grants (
  id bigint generated always as identity primary key,
  billing_principal_id uuid not null references public.billing_principals,
  purchase_token_hash text,
  order_id text,
  grant_cause text not null check (
    grant_cause in (
      'legacy_snapshot', 'initial_activation', 'rtdn_renewal',
      'resubscription_activation', 'recovery_activation'
    )
  ),
  event_key text not null unique,
  notification_type integer,
  credits integer not null check (credits > 0),
  balance_delta integer not null default 0,
  period_ends_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  granted_at timestamptz not null default now(),
  constraint monetization_allowance_grants_token_hash_check check (
    purchase_token_hash is null
    or purchase_token_hash ~ '^[0-9a-f]{64}$'
  ),
  constraint monetization_allowance_grants_order_id_check check (
    order_id is null or nullif(btrim(order_id), '') is not null
  ),
  constraint monetization_allowance_grants_cause_check check (
    (grant_cause = 'legacy_snapshot' and notification_type is null)
    or (
      grant_cause = 'initial_activation'
      and order_id is not null
      and notification_type is null
    )
    or (
      grant_cause = 'rtdn_renewal'
      and order_id is not null
      and notification_type = 2
    )
    or (
      grant_cause = 'resubscription_activation'
      and order_id is not null
      and (notification_type is null or notification_type = 4)
    )
    or (
      grant_cause = 'recovery_activation'
      and order_id is not null
      and (
        notification_type is null
        or notification_type in (1, 4)
      )
    )
  )
);

create unique index monetization_allowance_grants_order_idx
  on public.monetization_allowance_grants (order_id)
  where order_id is not null;
create unique index monetization_allowance_grants_initial_idx
  on public.monetization_allowance_grants (billing_principal_id)
  where grant_cause in ('legacy_snapshot', 'initial_activation');
create unique index monetization_allowance_grants_resubscribe_token_idx
  on public.monetization_allowance_grants (purchase_token_hash)
  where grant_cause = 'resubscription_activation';
create unique index monetization_allowance_grants_resubscribe_lapse_idx
  on public.monetization_allowance_grants (
    billing_principal_id, ((metadata->>'predecessorTokenHash'))
  )
  where grant_cause = 'resubscription_activation';
create unique index monetization_allowance_grants_recovery_period_idx
  on public.monetization_allowance_grants (
    billing_principal_id, purchase_token_hash, period_ends_at
  )
  where grant_cause = 'recovery_activation';

create table public.monetization_provider_recheck_queue (
  id bigint generated always as identity primary key,
  billing_principal_id uuid not null references public.billing_principals,
  purchase_token_hash text not null
    check (purchase_token_hash ~ '^[0-9a-f]{64}$'),
  product_id text not null check (
    product_id in (
      'chronospark_premium_monthly', 'chronospark_premium_annual'
    )
  ),
  provider_expires_at timestamptz not null,
  state text not null default 'pending'
    check (state in ('pending', 'processing', 'reconciled')),
  reason text not null default 'stored_expiry_due',
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  lease_id uuid,
  lease_until timestamptz,
  last_error_code text,
  enqueued_at timestamptz not null default now(),
  claimed_at timestamptz,
  reconciled_at timestamptz,
  provider_event_time timestamptz,
  resolution text,
  updated_at timestamptz not null default now(),
  constraint monetization_provider_recheck_resolution_check check (
    resolution is null
    or resolution in (
      'pending', 'active', 'grace', 'on_hold', 'paused', 'canceled', 'expired',
      'revoked', 'old_token', 'terminal_preserved',
      'refunded_old_token', 'refunded'
    )
  ),
  constraint monetization_provider_recheck_reconciled_check check (
    state <> 'reconciled'
    or (
      reconciled_at is not null
      and provider_event_time is not null
      and resolution is not null
    )
  ),
  unique (purchase_token_hash, provider_expires_at)
);

create index monetization_provider_recheck_pending_idx
  on public.monetization_provider_recheck_queue (next_attempt_at, enqueued_at)
  where state in ('pending', 'processing');

alter table public.monetization_allowance_grants enable row level security;
alter table public.monetization_provider_recheck_queue enable row level security;

insert into public.monetization_allowance_grants (
  billing_principal_id, purchase_token_hash, order_id, grant_cause,
  event_key, notification_type, credits, balance_delta, period_ends_at,
  metadata
)
select bp.billing_principal_id,
  status.purchase_token_hash,
  null,
  'legacy_snapshot',
  'phase8:legacy:' || bp.billing_principal_id::text,
  null,
  greatest(coalesce(wallet.period_credits, status.period_credits, 20), 1),
  0,
  coalesce(wallet.period_ends_at, status.expires_at),
  jsonb_build_object('source', 'phase8_backfill')
from public.billing_principals bp
left join public.monetization_subscription_statuses status
  using (billing_principal_id)
left join public.monetization_wallets wallet using (billing_principal_id)
where exists (
  select 1 from public.purchase_bindings binding
  where binding.billing_principal_id = bp.billing_principal_id
)
or status.billing_principal_id is not null
or exists (
  select 1 from public.monetization_purchases purchase
  where purchase.billing_principal_id = bp.billing_principal_id
)
on conflict do nothing;

create or replace function public.assign_billing_principal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_retired_at timestamptz;
begin
  if new.billing_principal_id is null then
    if new.user_id is null then
      raise exception 'billing principal required';
    end if;
    select billing_principal_id into new.billing_principal_id
    from public.billing_principals
    where current_user_id = new.user_id
      and retired_at is null;
    if new.billing_principal_id is null then
      raise exception 'billing principal not found';
    end if;
  end if;

  select current_user_id, retired_at into v_owner, v_retired_at
  from public.billing_principals
  where billing_principal_id = new.billing_principal_id;
  if not found then
    raise exception 'billing principal unavailable';
  end if;
  if v_retired_at is not null then
    if tg_op = 'UPDATE' then
      if new.user_id is null
        and old.billing_principal_id = new.billing_principal_id then
        return new;
      end if;
    end if;
    raise exception 'billing principal unavailable';
  end if;
  if new.user_id is not null and new.user_id is distinct from v_owner then
    raise exception 'billing principal owner mismatch';
  end if;
  return new;
end;
$$;

create trigger assign_purchase_binding_principal
before insert or update of user_id, billing_principal_id
on public.purchase_bindings
for each row execute function public.assign_billing_principal();
create trigger assign_subscription_status_principal
before insert or update of user_id, billing_principal_id
on public.monetization_subscription_statuses
for each row execute function public.assign_billing_principal();
create trigger assign_wallet_principal
before insert or update of user_id, billing_principal_id
on public.monetization_wallets
for each row execute function public.assign_billing_principal();
create trigger assign_credit_transaction_principal
before insert or update of user_id, billing_principal_id
on public.monetization_credit_transactions
for each row execute function public.assign_billing_principal();
create trigger assign_purchase_principal
before insert or update of user_id, billing_principal_id
on public.monetization_purchases
for each row execute function public.assign_billing_principal();
create trigger assign_entitlement_event_principal
before insert or update of user_id, billing_principal_id
on public.monetization_entitlement_events
for each row execute function public.assign_billing_principal();
create trigger assign_ai_usage_principal
before insert or update of user_id, billing_principal_id
on public.ai_usage_requests
for each row execute function public.assign_billing_principal();

create or replace function public.sync_billing_principal_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.current_user_id is not distinct from old.current_user_id then
    return new;
  end if;
  if old.current_user_id is not null
    and new.current_user_id is null
    and new.retired_at is null then
    delete from public.planner_explanation_replays
    where user_id = old.current_user_id;
    delete from public.planner_explanation_quotes
    where user_id = old.current_user_id;
    update public.ai_usage_requests
    set user_id = null, response_payload = '{}'::jsonb,
      provider_request_id = null
    where billing_principal_id = new.billing_principal_id
      and user_id = old.current_user_id;
  end if;
  update public.purchase_bindings set user_id = new.current_user_id
  where billing_principal_id = new.billing_principal_id;
  update public.monetization_subscription_statuses
  set user_id = new.current_user_id
  where billing_principal_id = new.billing_principal_id;
  update public.monetization_wallets set user_id = new.current_user_id
  where billing_principal_id = new.billing_principal_id;
  update public.monetization_credit_transactions
  set user_id = null
  where billing_principal_id = new.billing_principal_id;
  update public.monetization_purchases set user_id = null
  where billing_principal_id = new.billing_principal_id;
  update public.monetization_entitlement_events
  set user_id = null
  where billing_principal_id = new.billing_principal_id;
  return new;
end;
$$;

create trigger sync_billing_principal_user
after update of current_user_id on public.billing_principals
for each row execute function public.sync_billing_principal_user();

create or replace function public.ensure_billing_principal(p_user_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_principal_id uuid;
begin
  if p_user_id is null then
    raise exception 'valid user required';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:principal:' || p_user_id::text, 0)
  );
  select billing_principal_id into v_principal_id
  from public.billing_principals
  where current_user_id = p_user_id and retired_at is null
  for update;
  if not found then
    insert into public.billing_principals (
      current_user_id, attached_at, updated_at
    ) values (p_user_id, now(), now())
    returning billing_principal_id into v_principal_id;
  end if;
  return v_principal_id;
end;
$$;

create or replace function public.ensure_monetization_wallet_for_principal(
  p_billing_principal_id uuid
)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_principal public.billing_principals;
  v_wallet public.monetization_wallets;
begin
  select * into v_principal from public.billing_principals
  where billing_principal_id = p_billing_principal_id
    and retired_at is null
  for update;
  if not found then raise exception 'billing principal unavailable'; end if;

  insert into public.monetization_wallets (
    billing_principal_id, user_id, balance, allowance_remaining,
    bonus_balance, period_credits, lifetime_earned, lifetime_spent,
    tier, period_ends_at, updated_at
  ) values (
    p_billing_principal_id, v_principal.current_user_id,
    20, 20, 0, 20, 20, 0, 'free', now() + interval '1 day', now()
  ) on conflict (billing_principal_id) do nothing
  returning * into v_wallet;
  if found then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description
    ) values (
      p_billing_principal_id, v_principal.current_user_id,
      'initial_allowance', 20, 20, 'system', 'Initial daily allowance'
    );
  else
    select * into v_wallet from public.monetization_wallets
    where billing_principal_id = p_billing_principal_id for update;
  end if;
  return v_wallet;
end;
$$;

create or replace function public.ensure_monetization_wallet(p_user_id uuid)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = ''
as $$
begin
  return public.ensure_monetization_wallet_for_principal(
    public.ensure_billing_principal(p_user_id)
  );
end;
$$;

create or replace function public.sync_monetization_wallet_authority(
  p_billing_principal_id uuid,
  p_plan_id text,
  p_status text,
  p_is_active boolean,
  p_expires_at timestamptz,
  p_event_key text
)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_wallet public.monetization_wallets;
  v_user_id uuid;
  v_period_credits integer;
  v_old_balance integer;
  v_new_allowance integer;
begin
  if p_status in ('expired', 'revoked') and p_is_active then
    raise exception 'terminal subscription authority cannot be active';
  end if;
  v_wallet := public.ensure_monetization_wallet_for_principal(
    p_billing_principal_id
  );
  select current_user_id into v_user_id from public.billing_principals
  where billing_principal_id = p_billing_principal_id;
  v_period_credits := case p_plan_id
    when 'premium_monthly' then 300
    when 'premium_yearly' then 360
    else 20
  end;

  if p_is_active then
    update public.monetization_wallets
    set tier = p_plan_id,
      period_credits = v_period_credits,
      period_ends_at = coalesce(p_expires_at, period_ends_at),
      updated_at = now()
    where billing_principal_id = p_billing_principal_id
    returning * into v_wallet;
    return v_wallet;
  end if;

  v_old_balance := v_wallet.balance;
  v_new_allowance := least(v_wallet.allowance_remaining, 20);
  update public.monetization_wallets
  set balance = bonus_balance + v_new_allowance,
    allowance_remaining = v_new_allowance,
    period_credits = 20,
    tier = 'free',
    period_ends_at = now() + interval '1 day',
    updated_at = now()
  where billing_principal_id = p_billing_principal_id
  returning * into v_wallet;
  if v_wallet.balance <> v_old_balance then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description, metadata
    ) values (
      p_billing_principal_id, v_user_id, 'authority_adjustment',
      v_wallet.balance - v_old_balance, v_wallet.balance, 'google_play',
      'Provider authority reduced the available allowance',
      jsonb_build_object('status', p_status, 'eventKey', p_event_key)
    );
  end if;
  return v_wallet;
end;
$$;

create or replace function public.reset_monetization_allowance(p_user_id uuid)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_principal_id uuid;
  v_status public.monetization_subscription_statuses;
  v_wallet public.monetization_wallets;
  v_old_balance integer;
begin
  v_principal_id := public.ensure_billing_principal(p_user_id);
  v_wallet := public.ensure_monetization_wallet_for_principal(v_principal_id);
  select * into v_status from public.monetization_subscription_statuses
  where billing_principal_id = v_principal_id for update;

  if found and v_status.is_active
    and v_status.plan_id in ('premium_monthly', 'premium_yearly') then
    return public.sync_monetization_wallet_authority(
      v_principal_id, v_status.plan_id, v_status.status, true,
      v_status.expires_at, 'paid-period-provider-required'
    );
  end if;

  if v_wallet.tier <> 'free' then
    v_wallet := public.sync_monetization_wallet_authority(
      v_principal_id, 'free', coalesce(v_status.status, 'free'), false,
      null, 'free-authority-sync'
    );
  end if;
  if v_wallet.period_ends_at is not null and v_wallet.period_ends_at > now() then
    return v_wallet;
  end if;

  v_old_balance := v_wallet.balance;
  update public.monetization_wallets
  set balance = bonus_balance + 20,
    allowance_remaining = 20,
    period_credits = 20,
    lifetime_earned = lifetime_earned
      + greatest((bonus_balance + 20) - v_old_balance, 0),
    tier = 'free', period_ends_at = now() + interval '1 day',
    updated_at = now()
  where billing_principal_id = v_principal_id
  returning * into v_wallet;
  if v_wallet.balance <> v_old_balance then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description
    ) values (
      v_principal_id, p_user_id, 'allowance_reset',
      v_wallet.balance - v_old_balance, v_wallet.balance,
      'system', 'Free allowance reset'
    );
  end if;
  return v_wallet;
end;
$$;

create or replace function public.apply_monetization_allowance_grant(
  p_billing_principal_id uuid,
  p_purchase_token_hash text,
  p_order_id text,
  p_grant_cause text,
  p_event_key text,
  p_notification_type integer,
  p_credits integer,
  p_period_ends_at timestamptz
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_order_id text := nullif(btrim(p_order_id), '');
  v_grant_id bigint;
  v_wallet public.monetization_wallets;
  v_old_balance integer;
  v_delta integer;
  v_user_id uuid;
  v_predecessor_token_hash text;
begin
  if p_purchase_token_hash is null
    or p_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or v_order_id is null
    or nullif(btrim(p_event_key), '') is null
    or char_length(p_event_key) > 500
    or p_credits <= 0
    or p_grant_cause not in (
      'initial_activation', 'rtdn_renewal', 'resubscription_activation',
      'recovery_activation'
    )
    or (p_grant_cause = 'initial_activation' and p_notification_type is not null)
    or (p_grant_cause = 'rtdn_renewal' and p_notification_type <> 2)
    or (
      p_grant_cause = 'resubscription_activation'
      and p_notification_type is not null
      and p_notification_type <> 4
    )
    or (
      p_grant_cause = 'recovery_activation'
      and p_notification_type is not null
      and p_notification_type not in (1, 4)
    ) then
    return jsonb_build_object(
      'granted', false, 'reason', 'invalid_grant_cause', 'creditsGranted', 0
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:order:' || v_order_id, 0)
  );
  perform public.ensure_monetization_wallet_for_principal(
    p_billing_principal_id
  );

  if exists (
    select 1 from public.monetization_allowance_grants
    where order_id = v_order_id
  ) then
    return jsonb_build_object(
      'granted', false, 'reason', 'duplicate_order_id', 'creditsGranted', 0
    );
  end if;
  if p_grant_cause = 'initial_activation' and exists (
    select 1 from public.monetization_allowance_grants
    where billing_principal_id = p_billing_principal_id
  ) then
    return jsonb_build_object(
      'granted', false, 'reason', 'initial_already_granted',
      'creditsGranted', 0
    );
  end if;
  if p_grant_cause in (
    'resubscription_activation', 'recovery_activation'
  ) then
    select predecessor_token_hash into v_predecessor_token_hash
    from public.purchase_bindings
    where token_hash = p_purchase_token_hash;
    if p_grant_cause = 'resubscription_activation'
      and v_predecessor_token_hash is null then
      return jsonb_build_object(
        'granted', false, 'reason', 'resubscription_lineage_missing',
        'creditsGranted', 0
      );
    end if;
    if p_grant_cause = 'recovery_activation'
      and p_notification_type is distinct from 1
      and v_predecessor_token_hash is null then
      return jsonb_build_object(
        'granted', false, 'reason', 'recovery_lineage_missing',
        'creditsGranted', 0
      );
    end if;
  end if;

  insert into public.monetization_allowance_grants (
    billing_principal_id, purchase_token_hash, order_id, grant_cause,
    event_key, notification_type, credits, period_ends_at,
    metadata
  ) values (
    p_billing_principal_id, p_purchase_token_hash, v_order_id,
    p_grant_cause, p_event_key, p_notification_type, p_credits,
    p_period_ends_at, jsonb_strip_nulls(jsonb_build_object(
      'source', 'google_play',
      'predecessorTokenHash', v_predecessor_token_hash
    ))
  ) on conflict do nothing
  returning id into v_grant_id;
  if v_grant_id is null then
    return jsonb_build_object(
      'granted', false, 'reason', 'grant_duplicate', 'creditsGranted', 0
    );
  end if;

  select balance into v_old_balance from public.monetization_wallets
  where billing_principal_id = p_billing_principal_id for update;
  update public.monetization_wallets
  set balance = bonus_balance + p_credits,
    allowance_remaining = p_credits,
    period_credits = p_credits,
    lifetime_earned = lifetime_earned
      + greatest((bonus_balance + p_credits) - v_old_balance, 0),
    tier = case p_credits when 300 then 'premium_monthly'
      when 360 then 'premium_yearly' else tier end,
    period_ends_at = p_period_ends_at,
    updated_at = now()
  where billing_principal_id = p_billing_principal_id
  returning * into v_wallet;
  v_delta := v_wallet.balance - v_old_balance;
  update public.monetization_allowance_grants
  set balance_delta = v_delta where id = v_grant_id;
  select current_user_id into v_user_id from public.billing_principals
  where billing_principal_id = p_billing_principal_id;
  if v_delta <> 0 then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description, metadata
    ) values (
      p_billing_principal_id, v_user_id, 'allowance_grant', v_delta,
      v_wallet.balance, 'google_play', 'Provider-confirmed allowance grant',
      jsonb_build_object(
        'grantCause', p_grant_cause, 'orderId', v_order_id,
        'eventKey', p_event_key
      )
    );
  end if;
  return jsonb_build_object(
    'granted', true, 'reason', 'granted',
    'creditsGranted', greatest(v_delta, 0),
    'allowance', p_credits, 'balance', v_wallet.balance
  );
end;
$$;

create or replace function public.complete_monetization_provider_rechecks(
  p_purchase_token_hash text,
  p_provider_event_time timestamptz,
  p_resolution text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if p_purchase_token_hash is null
    or p_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or p_provider_event_time is null
    or p_resolution is null
    or p_resolution not in (
      'pending', 'active', 'grace', 'on_hold', 'paused', 'canceled',
      'expired', 'revoked', 'old_token', 'terminal_preserved',
      'refunded_old_token', 'refunded'
    ) then
    raise exception 'invalid authoritative provider recheck completion';
  end if;
  update public.monetization_provider_recheck_queue
  set state = 'reconciled', reconciled_at = now(),
    provider_event_time = p_provider_event_time,
    resolution = p_resolution, lease_id = null, lease_until = null,
    updated_at = now()
  where purchase_token_hash = p_purchase_token_hash
    and state in ('pending', 'processing')
    and p_provider_event_time >= provider_expires_at;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.claim_monetization_provider_rechecks(
  p_lease_id uuid,
  p_batch_size integer default 25,
  p_lease_seconds integer default 300
)
returns table (
  recheck_id bigint,
  purchase_token_hash text,
  product_id text,
  provider_expires_at timestamptz,
  lease_until timestamptz,
  attempts integer
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_lease_id is null
    or p_batch_size not between 1 and 100
    or p_lease_seconds not between 30 and 900 then
    raise exception 'invalid provider recheck claim';
  end if;
  return query
  with candidates as (
    select queue.id
    from public.monetization_provider_recheck_queue queue
    where (
      queue.state = 'pending'
      or (
        queue.state = 'processing'
        and queue.lease_until is not null
        and queue.lease_until <= now()
      )
    )
      and queue.next_attempt_at <= now()
    order by queue.next_attempt_at, queue.enqueued_at, queue.id
    for update skip locked
    limit p_batch_size
  ), claimed as (
    update public.monetization_provider_recheck_queue queue
    set state = 'processing', lease_id = p_lease_id,
      lease_until = now() + make_interval(secs => p_lease_seconds),
      attempts = queue.attempts + 1, claimed_at = now(),
      last_error_code = null, updated_at = now()
    from candidates
    where queue.id = candidates.id
    returning queue.id, queue.purchase_token_hash, queue.product_id,
      queue.provider_expires_at, queue.lease_until, queue.attempts
  )
  select claimed.id, claimed.purchase_token_hash, claimed.product_id,
    claimed.provider_expires_at, claimed.lease_until, claimed.attempts
  from claimed order by claimed.id;
end;
$$;

create or replace function public.finish_monetization_provider_recheck(
  p_recheck_id bigint,
  p_lease_id uuid,
  p_provider_event_time timestamptz,
  p_resolution text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception
    'provider recheck completion requires authoritative reconciliation';
end;
$$;

create or replace function public.retry_monetization_provider_recheck(
  p_recheck_id bigint,
  p_lease_id uuid,
  p_error_code text,
  p_retry_after_seconds integer default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempts integer;
  v_backoff_seconds integer;
begin
  if p_recheck_id is null or p_lease_id is null
    or p_error_code is null
    or p_error_code !~ '^[a-z0-9_.:-]{1,100}$'
    or (
      p_retry_after_seconds is not null
      and p_retry_after_seconds not between 30 and 21600
    ) then
    raise exception 'invalid provider recheck retry';
  end if;
  select attempts into v_attempts
  from public.monetization_provider_recheck_queue
  where id = p_recheck_id and state = 'processing'
    and lease_id = p_lease_id and lease_until > now()
  for update;
  if not found then return false; end if;
  v_backoff_seconds := coalesce(
    p_retry_after_seconds,
    least(21600, (30 * power(2, least(v_attempts, 10)))::integer)
  );
  update public.monetization_provider_recheck_queue
  set state = 'pending', next_attempt_at = now()
      + make_interval(secs => v_backoff_seconds),
    lease_id = null, lease_until = null,
    last_error_code = p_error_code, updated_at = now()
  where id = p_recheck_id and state = 'processing'
    and lease_id = p_lease_id;
  return found;
end;
$$;

create or replace function public.bind_verified_purchase_token(
  p_purchase_token_hash text,
  p_user_id uuid,
  p_product_id text,
  p_bound_at timestamptz,
  p_predecessor_token_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_predecessor public.purchase_bindings;
  v_principal public.billing_principals;
  v_user_principal public.billing_principals;
  v_bootstrap_wallet public.monetization_wallets;
  v_principal_id uuid;
  v_reserved_usage public.ai_usage_requests;
  v_bootstrap_is_free_only boolean := false;
  v_inserted boolean := false;
  v_lineage_enriched boolean := false;
begin
  if p_purchase_token_hash is null
    or p_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or p_user_id is null
    or p_product_id is null
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
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chronospark:principal:' || p_user_id::text, 0)
  );

  select * into v_binding from public.purchase_bindings
  where token_hash = p_purchase_token_hash for update;
  if found then
    if v_binding.product_id <> p_product_id then
      return jsonb_build_object('bound', false, 'reason', 'binding_mismatch');
    end if;
    v_principal_id := v_binding.billing_principal_id;
  end if;

  if p_predecessor_token_hash is not null then
    select * into v_predecessor from public.purchase_bindings
    where token_hash = p_predecessor_token_hash for update;
    if not found then
      return jsonb_build_object(
        'bound', false, 'reason', 'predecessor_unresolved'
      );
    end if;
    if v_principal_id is not null
      and v_principal_id <> v_predecessor.billing_principal_id then
      return jsonb_build_object(
        'bound', false, 'reason', 'predecessor_principal_mismatch'
      );
    end if;
    v_principal_id := v_predecessor.billing_principal_id;
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
    if v_binding.token_hash is not null then
      if v_binding.predecessor_token_hash is null then
        update public.purchase_bindings
        set predecessor_token_hash = p_predecessor_token_hash
        where token_hash = p_purchase_token_hash
          and predecessor_token_hash is null
        returning * into v_binding;
        v_lineage_enriched := found;
      elsif v_binding.predecessor_token_hash <> p_predecessor_token_hash then
        return jsonb_build_object('bound', false, 'reason', 'lineage_mismatch');
      end if;
    end if;
  end if;

  if v_principal_id is null then
    select * into v_user_principal from public.billing_principals
    where current_user_id = p_user_id and retired_at is null for update;
    if found then
      v_principal_id := v_user_principal.billing_principal_id;
    else
      insert into public.billing_principals (
        current_user_id, attached_at, updated_at
      ) values (p_user_id, p_bound_at, now())
      returning billing_principal_id into v_principal_id;
    end if;
  end if;

  select * into v_principal from public.billing_principals
  where billing_principal_id = v_principal_id for update;
  if not found then
    return jsonb_build_object('bound', false, 'reason', 'principal_unresolved');
  end if;
  if v_principal.retired_at is not null then
    return jsonb_build_object('bound', false, 'reason', 'principal_retired');
  end if;
  if v_principal.current_user_id is not null
    and v_principal.current_user_id <> p_user_id then
    return jsonb_build_object('bound', false, 'reason', 'binding_owned');
  end if;

  select * into v_user_principal from public.billing_principals
  where current_user_id = p_user_id and retired_at is null for update;
  if found and v_user_principal.billing_principal_id <> v_principal_id then
    v_bootstrap_is_free_only := not exists (
      select 1 from public.purchase_bindings
      where billing_principal_id = v_user_principal.billing_principal_id
    ) and not exists (
      select 1 from public.monetization_allowance_grants
      where billing_principal_id = v_user_principal.billing_principal_id
    ) and not exists (
      select 1 from public.monetization_purchases
      where billing_principal_id = v_user_principal.billing_principal_id
    ) and not exists (
      select 1 from public.monetization_subscription_statuses
      where billing_principal_id = v_user_principal.billing_principal_id
    ) and not exists (
      select 1 from public.monetization_entitlement_events
      where billing_principal_id = v_user_principal.billing_principal_id
    ) and not exists (
      select 1 from public.monetization_provider_recheck_queue
      where billing_principal_id = v_user_principal.billing_principal_id
    ) and not exists (
      select 1 from public.monetization_credit_transactions
      where billing_principal_id = v_user_principal.billing_principal_id
        and (
          type not in (
            'initial_allowance', 'allowance_reset', 'spend', 'refund'
          )
          or source not in ('system', 'ai_proxy')
        )
    );

    select * into v_bootstrap_wallet from public.monetization_wallets
    where billing_principal_id = v_user_principal.billing_principal_id
    for update;

    if v_bootstrap_wallet.billing_principal_id is null then
      v_bootstrap_is_free_only := v_bootstrap_is_free_only
        and not exists (
          select 1 from public.monetization_credit_transactions
          where billing_principal_id = v_user_principal.billing_principal_id
        )
        and not exists (
          select 1 from public.ai_usage_requests
          where billing_principal_id = v_user_principal.billing_principal_id
            and state <> 'denied'
        );
    else
      v_bootstrap_is_free_only := v_bootstrap_is_free_only
        and v_bootstrap_wallet.balance between 0 and 20
        and v_bootstrap_wallet.allowance_remaining between 0 and 20
        and v_bootstrap_wallet.balance = v_bootstrap_wallet.allowance_remaining
        and v_bootstrap_wallet.bonus_balance = 0
        and v_bootstrap_wallet.period_credits = 20
        and v_bootstrap_wallet.tier = 'free'
        and v_bootstrap_wallet.lifetime_earned >= 20
        and v_bootstrap_wallet.lifetime_spent >= 0
        and exists (
          select 1 from public.monetization_credit_transactions
          where billing_principal_id = v_user_principal.billing_principal_id
            and type = 'initial_allowance'
            and amount = 20
            and balance_after = 20
            and source = 'system'
            and description = 'Initial daily allowance'
            and metadata = '{}'::jsonb
        );
    end if;

    if not v_bootstrap_is_free_only then
      return jsonb_build_object(
        'bound', false, 'reason', 'user_principal_mismatch'
      );
    end if;

    for v_reserved_usage in
      select * from public.ai_usage_requests
      where billing_principal_id = v_user_principal.billing_principal_id
        and state = 'reserved'
      order by created_at
      for update
    loop
      perform public.settle_ai_usage_for_principal(
        v_user_principal.billing_principal_id,
        v_reserved_usage.request_key,
        false,
        null,
        null,
        null,
        'principal_reattached',
        '{}'::jsonb
      );
    end loop;
    update public.ai_usage_requests
    set user_id = null, response_payload = '{}'::jsonb,
      provider_request_id = null
    where billing_principal_id = v_user_principal.billing_principal_id;
    update public.billing_principals
    set current_user_id = null, retired_at = now(), detached_at = now(),
      updated_at = now()
    where billing_principal_id = v_user_principal.billing_principal_id;
  end if;

  if v_principal.current_user_id is null then
    update public.billing_principals
    set current_user_id = p_user_id, attached_at = p_bound_at,
      updated_at = now()
    where billing_principal_id = v_principal_id;
  end if;

  if v_binding.token_hash is null then
    insert into public.purchase_bindings (
      token_hash, user_id, product_id, created_at,
      predecessor_token_hash, billing_principal_id
    ) values (
      p_purchase_token_hash, p_user_id, p_product_id, p_bound_at,
      p_predecessor_token_hash, v_principal_id
    ) returning * into v_binding;
    v_inserted := true;
  end if;

  return jsonb_build_object(
    'bound', true,
    'reason', case
      when v_inserted then 'bound'
      when v_lineage_enriched then 'lineage_enriched'
      else 'already_bound'
    end,
    'duplicate', not v_inserted,
    'userId', p_user_id,
    'billingPrincipalId', v_principal_id,
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

create or replace function public.bind_verified_linked_purchase_token(
  p_purchase_token_hash text,
  p_predecessor_token_hash text,
  p_product_id text,
  p_bound_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_predecessor public.purchase_bindings;
  v_binding public.purchase_bindings;
  v_principal public.billing_principals;
  v_inserted boolean := false;
  v_lineage_enriched boolean := false;
begin
  if p_purchase_token_hash is null
    or p_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or p_predecessor_token_hash is null
    or p_predecessor_token_hash !~ '^[0-9a-f]{64}$'
    or p_purchase_token_hash = p_predecessor_token_hash
    or p_product_id is null
    or p_product_id not in (
      'chronospark_premium_monthly', 'chronospark_premium_annual'
    )
    or p_bound_at is null then
    raise exception 'invalid linked purchase binding';
  end if;

  if p_purchase_token_hash < p_predecessor_token_hash then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_purchase_token_hash, 0)
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_predecessor_token_hash, 0)
    );
  else
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_predecessor_token_hash, 0)
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_purchase_token_hash, 0)
    );
  end if;

  select * into v_predecessor from public.purchase_bindings
  where token_hash = p_predecessor_token_hash for update;
  if not found then
    return jsonb_build_object('bound', false, 'reason', 'predecessor_unresolved');
  end if;
  select * into v_principal from public.billing_principals
  where billing_principal_id = v_predecessor.billing_principal_id for update;
  if not found then
    return jsonb_build_object('bound', false, 'reason', 'principal_unresolved');
  end if;
  if v_principal.retired_at is not null then
    return jsonb_build_object('bound', false, 'reason', 'principal_retired');
  end if;
  if v_predecessor.user_id is distinct from v_principal.current_user_id then
    return jsonb_build_object(
      'bound', false, 'reason', 'predecessor_owner_mismatch'
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

  select * into v_binding from public.purchase_bindings
  where token_hash = p_purchase_token_hash for update;
  if found then
    if v_binding.billing_principal_id <> v_principal.billing_principal_id
      or v_binding.product_id <> p_product_id then
      return jsonb_build_object('bound', false, 'reason', 'binding_mismatch');
    end if;
    if v_binding.predecessor_token_hash is null then
      update public.purchase_bindings
      set predecessor_token_hash = p_predecessor_token_hash
      where token_hash = p_purchase_token_hash
        and predecessor_token_hash is null
      returning * into v_binding;
      v_lineage_enriched := found;
    elsif v_binding.predecessor_token_hash <> p_predecessor_token_hash then
      return jsonb_build_object('bound', false, 'reason', 'lineage_mismatch');
    end if;
  else
    insert into public.purchase_bindings (
      token_hash, user_id, product_id, created_at,
      predecessor_token_hash, billing_principal_id
    ) values (
      p_purchase_token_hash, v_principal.current_user_id, p_product_id,
      p_bound_at, p_predecessor_token_hash,
      v_principal.billing_principal_id
    ) returning * into v_binding;
    v_inserted := true;
  end if;

  return jsonb_build_object(
    'bound', true,
    'reason', case
      when v_inserted then 'linked_successor_bound'
      when v_lineage_enriched then 'lineage_enriched'
      else 'already_bound'
    end,
    'duplicate', not v_inserted,
    'userId', v_principal.current_user_id,
    'billingPrincipalId', v_principal.billing_principal_id,
    'predecessorTokenHash', p_predecessor_token_hash
  );
end;
$$;

drop function if exists public.reconcile_google_play_subscription(
  text, text, text, boolean, boolean, text, timestamptz, text, jsonb
);

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
security definer
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_current_binding public.purchase_bindings;
  v_principal public.billing_principals;
  v_current public.monetization_subscription_statuses;
  v_purchase public.monetization_purchases;
  v_plan_id text;
  v_period_credits integer;
  v_wallet public.monetization_wallets;
  v_payload jsonb;
  v_source text;
  v_order_id text := nullif(btrim(p_order_id), '');
  v_notification_type integer;
  v_event_count integer;
  v_incoming_is_predecessor boolean := false;
  v_current_is_predecessor boolean := false;
  v_grant jsonb := jsonb_build_object(
    'granted', false, 'reason', 'not_paid_grant_cause', 'creditsGranted', 0
  );
  v_grant_cause text;
  v_event_type text;
  v_is_lapsed_resubscription boolean := false;
  v_is_late_lapsed_resubscription boolean := false;
  v_is_same_token_recovery boolean := false;
  v_is_hold_repurchase boolean := false;
  v_is_paid_recovery boolean := false;
begin
  if p_purchase_token_hash is null
    or p_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or p_status is null
    or p_status not in ('pending', 'active', 'grace', 'on_hold', 'paused',
      'canceled', 'expired', 'revoked')
    or p_is_active is null
    or p_auto_renews is null
    or nullif(btrim(p_event_key), '') is null
    or char_length(p_event_key) > 500 then
    raise exception 'unsupported subscription authority';
  end if;
  if p_provider_event_time is null then
    raise exception 'provider event time is required';
  end if;
  if p_status in ('expired', 'revoked')
    and (p_is_active or p_auto_renews) then
    raise exception 'terminal subscription authority cannot be active';
  end if;

  select * into v_binding from public.purchase_bindings
  where token_hash = p_purchase_token_hash for update;
  if not found or v_binding.product_id <> p_product_id then
    return jsonb_build_object('applied', false, 'reason', 'binding_not_found');
  end if;
  select * into v_principal from public.billing_principals
  where billing_principal_id = v_binding.billing_principal_id for update;
  if not found or v_principal.retired_at is not null then
    return jsonb_build_object('applied', false, 'reason', 'principal_unavailable');
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
  v_source := coalesce(v_payload->>'source', 'unknown');
  if jsonb_typeof(v_payload->'notificationType') = 'number' then
    v_notification_type := (v_payload->>'notificationType')::integer;
  elsif jsonb_typeof(v_payload->'notificationType') = 'string'
    and (v_payload->>'notificationType') ~ '^[0-9]+$' then
    v_notification_type := (v_payload->>'notificationType')::integer;
  end if;

  select * into v_current from public.monetization_subscription_statuses
  where billing_principal_id = v_binding.billing_principal_id for update;
  if v_current.billing_principal_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash then
    select * into v_current_binding from public.purchase_bindings
    where token_hash = v_current.purchase_token_hash;
    with recursive current_ancestry(token_hash, path) as (
      select v_current.purchase_token_hash, array[v_current.purchase_token_hash]
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
      select 1 from current_ancestry where token_hash = p_purchase_token_hash
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
  select * into v_purchase from public.monetization_purchases
  where purchase_token_hash = p_purchase_token_hash for update;

  v_is_lapsed_resubscription := p_status = 'active'
    and p_is_active
    and v_order_id is not null
    and v_current.billing_principal_id is not null
    and v_current.status = 'expired'
    and not v_current.is_active
    and v_current.metadata->>'source' = 'google_play_rtdn'
    and v_current.metadata->>'notificationType' = '13'
    and v_current.expires_at is not null
    and v_current.expires_at <= p_provider_event_time
    and v_current.provider_event_time < p_provider_event_time
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash
    and v_binding.predecessor_token_hash = v_current.purchase_token_hash
    and (
      v_source = 'client_verification'
      or (
        v_source = 'google_play_rtdn'
        and v_notification_type = 4
      )
    );

  v_is_late_lapsed_resubscription := p_status = 'expired'
    and not p_is_active
    and v_source = 'google_play_rtdn'
    and v_notification_type = 13
    and v_current.billing_principal_id is not null
    and v_current.is_active
    and v_current.status = 'active'
    and v_current.order_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash
    and v_incoming_is_predecessor
    and v_current_binding.predecessor_token_hash = p_purchase_token_hash
    and v_current.metadata->>'lineageSource' = 'out_of_app_resubscribe'
    and p_expires_at is not null
    and p_expires_at <= v_current.provider_event_time
    and (
      v_current.metadata->>'source' = 'client_verification'
      or (
        v_current.metadata->>'source' = 'google_play_rtdn'
        and v_current.metadata->>'notificationType' = '4'
      )
    );

  v_is_same_token_recovery := p_status = 'active'
    and p_is_active
    and v_order_id is not null
    and v_source = 'google_play_rtdn'
    and v_notification_type = 1
    and v_current.billing_principal_id is not null
    and not v_current.is_active
    and v_current.status in ('on_hold', 'paused')
    and v_current.purchase_token_hash = p_purchase_token_hash
    and v_current.order_id is distinct from v_order_id
    and v_current.provider_event_time < p_provider_event_time
    and p_expires_at is not null
    and (
      v_current.expires_at is null
      or p_expires_at > v_current.expires_at
    );

  v_is_hold_repurchase := p_status = 'active'
    and p_is_active
    and v_order_id is not null
    and v_current.billing_principal_id is not null
    and not v_current.is_active
    and v_current.status in ('on_hold', 'paused')
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash
    and v_binding.predecessor_token_hash = v_current.purchase_token_hash
    and v_current_is_predecessor
    and v_current.provider_event_time < p_provider_event_time
    and p_expires_at is not null
    and p_expires_at > p_provider_event_time
    and (
      v_source = 'client_verification'
      or (
        v_source = 'google_play_rtdn'
        and v_notification_type = 4
      )
    );
  v_is_paid_recovery := v_is_same_token_recovery or v_is_hold_repurchase;

  if v_current.billing_principal_id is not null
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
      billing_principal_id, user_id, event_key, event_type, plan_id,
      product_id, is_active, effective_at, expires_at, metadata
    ) values (
      v_binding.billing_principal_id, v_principal.current_user_id, p_event_key,
      'subscription_' || p_status || '_old_token', v_plan_id, p_product_id,
      p_is_active, p_provider_event_time, p_expires_at, v_payload
    ) on conflict (event_key) do nothing;
    insert into public.monetization_purchases (
      billing_principal_id, user_id, product_id, purchase_type,
      purchase_state, purchase_token_hash, order_id,
      subscription_plan_id, payload, verified_at
    ) values (
      v_binding.billing_principal_id, v_principal.current_user_id,
      p_product_id, 'subscription', p_status, p_purchase_token_hash,
      v_order_id, v_plan_id, v_payload, now()
    ) on conflict (purchase_token_hash) do update set
      purchase_state = case
        when public.monetization_purchases.purchase_state in (
          'refunded', 'revoked'
        )
          then public.monetization_purchases.purchase_state
        else excluded.purchase_state end,
      order_id = coalesce(excluded.order_id, public.monetization_purchases.order_id),
      payload = public.monetization_purchases.payload || excluded.payload,
      verified_at = now();
    perform public.complete_monetization_provider_rechecks(
      p_purchase_token_hash, p_provider_event_time, 'old_token'
    );
    if v_is_late_lapsed_resubscription then
      v_grant_cause := 'resubscription_activation';
      v_grant := public.apply_monetization_allowance_grant(
        v_binding.billing_principal_id, v_current.purchase_token_hash,
        v_current.order_id, v_grant_cause, p_event_key,
        case
          when v_current.metadata->>'source' = 'google_play_rtdn' then 4
          else null
        end,
        v_current.period_credits, v_current.expires_at
      );
      if (v_grant->>'granted')::boolean then
        update public.monetization_entitlement_events
        set event_type = 'subscription_resubscribed_late_expiry',
          metadata = metadata || jsonb_build_object(
            'allowanceGrantCause', v_grant_cause,
            'allowanceOrderId', v_current.order_id,
            'successorPurchaseTokenHash', v_current.purchase_token_hash
          )
        where event_key = p_event_key;
      end if;
    end if;
    return jsonb_build_object(
      'applied', false, 'handled', true, 'reason', 'old_token',
      'userId', v_principal.current_user_id,
      'active', v_current.is_active,
      'creditsGranted', coalesce((v_grant->>'creditsGranted')::integer, 0),
      'resubscribed', coalesce(
        v_grant_cause = 'resubscription_activation'
          and (v_grant->>'granted')::boolean,
        false
      )
    );
  end if;

  -- Terminal authority is evaluated before event-key dedupe.
  if (
    v_current.billing_principal_id is not null
    and v_current.purchase_token_hash is not distinct from p_purchase_token_hash
    and v_current.status = 'revoked'
  ) or v_purchase.purchase_state in ('refunded', 'revoked') then
    insert into public.monetization_entitlement_events (
      billing_principal_id, user_id, event_key, event_type, plan_id,
      product_id, is_active, effective_at, expires_at, metadata
    ) values (
      v_binding.billing_principal_id, v_principal.current_user_id, p_event_key,
      'subscription_terminal_token_ignored', v_plan_id, p_product_id,
      false, p_provider_event_time, p_expires_at, v_payload
    ) on conflict (event_key) do nothing;
    perform public.complete_monetization_provider_rechecks(
      p_purchase_token_hash, p_provider_event_time, 'terminal_preserved'
    );
    return jsonb_build_object(
      'applied', false, 'handled', true, 'reason', 'terminal_token',
      'userId', v_principal.current_user_id, 'active', false,
      'creditsGranted', 0
    );
  end if;

  if p_event_key is not null and exists (
    select 1 from public.monetization_entitlement_events
    where event_key = p_event_key
  ) then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_principal.current_user_id, 'creditsGranted', 0
    );
  end if;
  if v_current.billing_principal_id is not null and (
    v_current.provider_event_time > p_provider_event_time
    or (
      v_current.provider_event_time = p_provider_event_time
      and not v_current.is_active and p_is_active
      and not (
        p_expires_at is not null and v_current.expires_at is not null
        and p_expires_at > v_current.expires_at
      )
    )
  ) then
    insert into public.monetization_entitlement_events (
      billing_principal_id, user_id, event_key, event_type, plan_id,
      product_id, is_active, effective_at, expires_at, metadata
    ) values (
      v_binding.billing_principal_id, v_principal.current_user_id, p_event_key,
      'subscription_stale_ignored', v_plan_id, p_product_id, p_is_active,
      p_provider_event_time, p_expires_at, v_payload
    ) on conflict (event_key) do nothing;
    return jsonb_build_object(
      'applied', false, 'handled', true, 'stale', true,
      'reason', 'stale_event', 'userId', v_principal.current_user_id,
      'creditsGranted', 0
    );
  end if;

  v_event_type := 'subscription_' || p_status;
  insert into public.monetization_entitlement_events (
    billing_principal_id, user_id, event_key, event_type, plan_id,
    product_id, is_active, effective_at, expires_at, metadata
  ) values (
    v_binding.billing_principal_id, v_principal.current_user_id, p_event_key,
    v_event_type, v_plan_id, p_product_id, p_is_active,
    p_provider_event_time, p_expires_at, v_payload
  ) on conflict (event_key) do nothing;
  get diagnostics v_event_count = row_count;
  if p_event_key is not null and v_event_count = 0 then
    return jsonb_build_object(
      'applied', false, 'duplicate', true, 'handled', true,
      'userId', v_principal.current_user_id, 'creditsGranted', 0
    );
  end if;

  insert into public.monetization_subscription_statuses (
    billing_principal_id, user_id, plan_id, product_id, status,
    is_active, auto_renews, period_credits, started_at, expires_at,
    order_id, purchase_token_hash, provider_event_time, metadata, updated_at
  ) values (
    v_binding.billing_principal_id, v_principal.current_user_id,
    v_plan_id, p_product_id, p_status, p_is_active, p_auto_renews,
    v_period_credits, coalesce(v_current.started_at, now()), p_expires_at,
    v_order_id, p_purchase_token_hash, p_provider_event_time, v_payload, now()
  ) on conflict (billing_principal_id) do update set
    user_id = excluded.user_id, plan_id = excluded.plan_id,
    product_id = excluded.product_id, status = excluded.status,
    is_active = excluded.is_active, auto_renews = excluded.auto_renews,
    period_credits = excluded.period_credits,
    started_at = coalesce(
      public.monetization_subscription_statuses.started_at,
      excluded.started_at
    ),
    expires_at = excluded.expires_at,
    order_id = coalesce(excluded.order_id,
      public.monetization_subscription_statuses.order_id),
    purchase_token_hash = excluded.purchase_token_hash,
    provider_event_time = greatest(
      public.monetization_subscription_statuses.provider_event_time,
      excluded.provider_event_time
    ),
    metadata = excluded.metadata, updated_at = now();

  insert into public.monetization_purchases (
    billing_principal_id, user_id, product_id, purchase_type,
    purchase_state, purchase_token_hash, order_id,
    subscription_plan_id, payload, verified_at
  ) values (
    v_binding.billing_principal_id, v_principal.current_user_id,
    p_product_id, 'subscription', p_status, p_purchase_token_hash,
    v_order_id, v_plan_id, v_payload, now()
  ) on conflict (purchase_token_hash) do update set
    user_id = excluded.user_id,
    purchase_state = case
      when public.monetization_purchases.purchase_state in (
        'refunded', 'revoked'
      )
        then public.monetization_purchases.purchase_state
      else excluded.purchase_state end,
    order_id = coalesce(excluded.order_id, public.monetization_purchases.order_id),
    payload = public.monetization_purchases.payload || excluded.payload,
    verified_at = now();

  v_wallet := public.sync_monetization_wallet_authority(
    v_binding.billing_principal_id, v_plan_id, p_status, p_is_active,
    p_expires_at, p_event_key
  );

  if p_status = 'active' and p_is_active and v_order_id is not null
    and v_source = 'google_play_rtdn' and v_notification_type = 2 then
    v_grant_cause := 'rtdn_renewal';
    v_grant := public.apply_monetization_allowance_grant(
      v_binding.billing_principal_id, p_purchase_token_hash, v_order_id,
      v_grant_cause, p_event_key, 2, v_period_credits, p_expires_at
    );
  elsif v_is_paid_recovery then
    v_grant_cause := 'recovery_activation';
    v_grant := public.apply_monetization_allowance_grant(
      v_binding.billing_principal_id, p_purchase_token_hash, v_order_id,
      v_grant_cause, p_event_key,
      case
        when v_source = 'google_play_rtdn' then v_notification_type
        else null
      end,
      v_period_credits, p_expires_at
    );
  elsif v_is_lapsed_resubscription then
    v_grant_cause := 'resubscription_activation';
    v_grant := public.apply_monetization_allowance_grant(
      v_binding.billing_principal_id, p_purchase_token_hash, v_order_id,
      v_grant_cause, p_event_key,
      case when v_source = 'google_play_rtdn' then 4 else null end,
      v_period_credits, p_expires_at
    );
  elsif p_status = 'active' and p_is_active and v_order_id is not null
    and v_source = 'client_verification'
    and not exists (
      select 1 from public.monetization_allowance_grants
      where billing_principal_id = v_binding.billing_principal_id
    ) then
    v_grant_cause := 'initial_activation';
    v_grant := public.apply_monetization_allowance_grant(
      v_binding.billing_principal_id, p_purchase_token_hash, v_order_id,
      v_grant_cause, p_event_key, null, v_period_credits, p_expires_at
    );
  elsif p_status = 'active' and p_is_active
    and v_source = 'google_play_rtdn' and v_notification_type = 2
    and v_order_id is null then
    v_grant := jsonb_build_object(
      'granted', false, 'reason', 'missing_order_id', 'creditsGranted', 0
    );
  end if;

  if (v_grant->>'granted')::boolean then
    v_event_type := case v_grant_cause
      when 'rtdn_renewal' then 'subscription_renewed'
      when 'recovery_activation' then 'subscription_recovered'
      when 'resubscription_activation' then 'subscription_resubscribed'
      else 'subscription_activated'
    end;
    update public.monetization_entitlement_events
    set event_type = v_event_type,
      metadata = metadata || jsonb_build_object(
        'allowanceGrantCause', v_grant_cause,
        'allowanceOrderId', v_order_id
      )
    where event_key = p_event_key;
    select * into v_wallet from public.monetization_wallets
    where billing_principal_id = v_binding.billing_principal_id;
  end if;
  perform public.complete_monetization_provider_rechecks(
    p_purchase_token_hash, p_provider_event_time, p_status
  );
  return jsonb_build_object(
    'applied', true, 'handled', true,
    'userId', v_principal.current_user_id,
    'billingPrincipalId', v_binding.billing_principal_id,
    'planId', v_plan_id, 'eventType', v_event_type,
    'creditsGranted', coalesce((v_grant->>'creditsGranted')::integer, 0),
    'allowanceGrantReason', v_grant->>'reason',
    'remainingCredits', v_wallet.balance,
    'active', p_is_active,
    'renewed', coalesce(v_grant_cause = 'rtdn_renewal'
      and (v_grant->>'granted')::boolean, false),
    'recovered', coalesce(v_grant_cause = 'recovery_activation'
      and (v_grant->>'granted')::boolean, false),
    'resubscribed', coalesce(v_grant_cause = 'resubscription_activation'
      and (v_grant->>'granted')::boolean, false)
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
security definer
set search_path = ''
as $$
declare
  v_binding public.purchase_bindings;
  v_principal public.billing_principals;
  v_purchase public.monetization_purchases;
  v_current public.monetization_subscription_statuses;
  v_wallet public.monetization_wallets;
  v_payload jsonb;
  v_duplicate boolean := false;
begin
  if p_purchase_token_hash is null
    or p_purchase_token_hash !~ '^[0-9a-f]{64}$'
    or p_provider_event_time is null
    or nullif(btrim(p_event_key), '') is null
    or char_length(p_event_key) > 500 then
    raise exception 'invalid voided purchase authority';
  end if;
  select * into v_binding from public.purchase_bindings
  where token_hash = p_purchase_token_hash for update;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'binding_not_found');
  end if;
  select * into v_principal from public.billing_principals
  where billing_principal_id = v_binding.billing_principal_id for update;
  if not found or v_principal.retired_at is not null then
    return jsonb_build_object('applied', false, 'reason', 'principal_unavailable');
  end if;
  select * into v_purchase from public.monetization_purchases
  where purchase_token_hash = p_purchase_token_hash for update;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'purchase_not_found');
  end if;
  select * into v_current from public.monetization_subscription_statuses
  where billing_principal_id = v_binding.billing_principal_id for update;
  v_payload := coalesce(p_payload, '{}'::jsonb) || jsonb_build_object(
    'providerEventTime', p_provider_event_time
  );
  select exists (
    select 1 from public.monetization_entitlement_events
    where event_key = p_event_key
  ) into v_duplicate;

  if v_current.billing_principal_id is not null
    and v_current.purchase_token_hash is distinct from p_purchase_token_hash then
    insert into public.monetization_entitlement_events (
      billing_principal_id, user_id, event_key, event_type, plan_id,
      product_id, is_active, effective_at, metadata
    ) values (
      v_binding.billing_principal_id, v_principal.current_user_id, p_event_key,
      'purchase_refunded_old_token', v_purchase.subscription_plan_id,
      v_purchase.product_id, false, p_provider_event_time, v_payload
    ) on conflict (event_key) do nothing;
    update public.monetization_purchases
    set purchase_state = 'refunded',
      order_id = coalesce(nullif(btrim(p_order_id), ''), order_id),
      payload = payload || v_payload, verified_at = now()
    where id = v_purchase.id;
    perform public.complete_monetization_provider_rechecks(
      p_purchase_token_hash, p_provider_event_time, 'refunded_old_token'
    );
    return jsonb_build_object(
      'applied', true, 'duplicate', v_duplicate, 'handled', true,
      'reason', 'old_token',
      'userId', v_principal.current_user_id,
      'productId', v_purchase.product_id, 'currentPreserved', true
    );
  end if;

  insert into public.monetization_entitlement_events (
    billing_principal_id, user_id, event_key, event_type, plan_id,
    product_id, is_active, effective_at, metadata
  ) values (
    v_binding.billing_principal_id, v_principal.current_user_id, p_event_key,
    'purchase_refunded', v_purchase.subscription_plan_id,
    v_purchase.product_id, false, p_provider_event_time, v_payload
  ) on conflict (event_key) do nothing;
  update public.monetization_purchases
  set purchase_state = 'refunded',
    order_id = coalesce(nullif(btrim(p_order_id), ''), order_id),
    payload = payload || v_payload, verified_at = now()
  where id = v_purchase.id;
  update public.monetization_subscription_statuses
  set status = 'revoked', is_active = false, auto_renews = false,
    provider_event_time = greatest(provider_event_time, p_provider_event_time),
    metadata = metadata || v_payload, updated_at = now()
  where billing_principal_id = v_binding.billing_principal_id
    and purchase_token_hash = p_purchase_token_hash;
  v_wallet := public.sync_monetization_wallet_authority(
    v_binding.billing_principal_id, v_current.plan_id, 'revoked', false,
    v_current.expires_at, p_event_key
  );
  perform public.complete_monetization_provider_rechecks(
    p_purchase_token_hash, p_provider_event_time, 'refunded'
  );
  return jsonb_build_object(
    'applied', true, 'duplicate', v_duplicate, 'handled', true,
    'userId', v_principal.current_user_id,
    'productId', v_purchase.product_id,
    'remainingCredits', v_wallet.balance, 'active', false
  );
end;
$$;

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
begin
  if p_billing_principal_id is null
    or p_request_key is null
    or p_request_key !~ '^[A-Za-z0-9._:=+-]{8,200}$'
    or p_credit_amount is null
    or p_credit_amount not between 1 and 3
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
      'responsePayload', v_existing.response_payload
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

  v_bonus_used := least(v_wallet.bonus_balance, p_credit_amount);
  v_allowance_used := p_credit_amount - v_bonus_used;
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
    bonus_used, allowance_used, prompt_hash
  ) values (
    p_billing_principal_id, v_principal.current_user_id, p_request_key,
    'reserved', p_credit_amount, v_bonus_used, v_allowance_used, p_prompt_hash
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
begin
  return public.reserve_ai_usage_for_principal(
    public.ensure_billing_principal(p_user_id), p_request_key,
    p_credit_amount, p_prompt_hash
  );
end;
$$;

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
  if v_effective_success then
    update public.ai_usage_requests set state = 'completed',
      input_tokens = greatest(coalesce(p_input_tokens, 0), 0),
      output_tokens = greatest(coalesce(p_output_tokens, 0), 0),
      provider_request_id = left(p_provider_request_id, 200),
      response_payload = coalesce(p_response_payload, '{}'::jsonb),
      settled_at = now()
    where id = v_usage.id;
    return jsonb_build_object('state', 'completed', 'refunded', false);
  end if;

  select * into v_wallet from public.monetization_wallets
  where billing_principal_id = p_billing_principal_id for update;
  if not found then raise exception 'billing wallet not found'; end if;
  update public.monetization_wallets set
    bonus_balance = bonus_balance + v_usage.bonus_used,
    allowance_remaining = allowance_remaining + v_usage.allowance_used,
    balance = balance + v_usage.credit_amount,
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
    failure_code = left(v_failure_code, 100), settled_at = now()
  where id = v_usage.id;
  if v_principal.retired_at is null then
    insert into public.monetization_credit_transactions (
      billing_principal_id, user_id, type, amount, balance_after,
      source, description, metadata
    ) values (
      p_billing_principal_id, v_principal.current_user_id, 'refund',
      v_usage.credit_amount, v_wallet.balance, 'ai_proxy',
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
begin
  return public.settle_ai_usage_for_principal(
    public.ensure_billing_principal(p_user_id), p_request_key, p_succeeded,
    p_input_tokens, p_output_tokens, p_provider_request_id, p_failure_code,
    p_response_payload
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
  v_count integer := 0;
begin
  for v_usage in select * from public.ai_usage_requests
    where state = 'reserved' and created_at < now() - p_older_than
    order by created_at for update skip locked
  loop
    perform public.settle_ai_usage_for_principal(
      v_usage.billing_principal_id, v_usage.request_key, false,
      null, null, null, 'reservation_timeout', '{}'::jsonb
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.expire_stale_monetization_subscriptions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  insert into public.monetization_provider_recheck_queue (
    billing_principal_id, purchase_token_hash, product_id,
    provider_expires_at, state, reason, enqueued_at, updated_at
  )
  select status.billing_principal_id, status.purchase_token_hash,
    status.product_id, status.expires_at, 'pending',
    'stored_expiry_due', now(), now()
  from public.monetization_subscription_statuses status
  join public.billing_principals principal using (billing_principal_id)
  where status.is_active = true
    and status.expires_at is not null
    and status.expires_at <= now()
    and status.purchase_token_hash is not null
    and principal.retired_at is null
  on conflict (purchase_token_hash, provider_expires_at) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on table public.billing_principals
  from public, anon, authenticated, service_role;
revoke all on table public.monetization_allowance_grants
  from public, anon, authenticated, service_role;
revoke all on table public.monetization_provider_recheck_queue
  from public, anon, authenticated, service_role;
grant select on table public.billing_principals to service_role;
grant insert (current_user_id, attached_at, updated_at)
  on table public.billing_principals to service_role;
grant update (updated_at) on table public.billing_principals to service_role;
grant select, insert on table public.monetization_allowance_grants
  to service_role;
grant update (balance_delta) on table public.monetization_allowance_grants
  to service_role;
grant usage, select on sequence public.monetization_allowance_grants_id_seq
  to service_role;
revoke update (predecessor_token_hash)
  on table public.purchase_bindings from service_role;

revoke select on table public.monetization_subscription_statuses
  from authenticated;
grant select (
  user_id, plan_id, product_id, status, is_active, expires_at, updated_at
) on table public.monetization_subscription_statuses to authenticated;
revoke select on table public.monetization_wallets from authenticated;
grant select (
  balance, tier, period_credits, period_ends_at, updated_at
) on table public.monetization_wallets to authenticated;
revoke all on table public.monetization_credit_transactions
  from public, anon, authenticated;
revoke all on table public.monetization_purchases
  from public, anon, authenticated;
revoke all on table public.monetization_entitlement_events
  from public, anon, authenticated;
drop policy if exists "monetization ledger select own"
  on public.monetization_credit_transactions;
drop policy if exists "monetization purchases select own"
  on public.monetization_purchases;
drop policy if exists "monetization events select own"
  on public.monetization_entitlement_events;

revoke all on function public.assign_billing_principal()
  from public, anon, authenticated, service_role;
revoke all on function public.sync_billing_principal_user()
  from public, anon, authenticated, service_role;
revoke all on function public.ensure_billing_principal(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.ensure_monetization_wallet_for_principal(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.reserve_ai_usage_for_principal(
  uuid, text, integer, text
) from public, anon, authenticated, service_role;
revoke all on function public.reserve_ai_usage(uuid, text, integer, text)
  from public, anon, authenticated, service_role;
revoke all on function public.settle_ai_usage_for_principal(
  uuid, text, boolean, integer, integer, text, text, jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.settle_ai_usage(
  uuid, text, boolean, integer, integer, text, text, jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.sync_monetization_wallet_authority(
  uuid, text, text, boolean, timestamptz, text
) from public, anon, authenticated, service_role;
revoke all on function public.apply_monetization_allowance_grant(
  uuid, text, text, text, text, integer, integer, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.complete_monetization_provider_rechecks(
  text, timestamptz, text
) from public, anon, authenticated, service_role;
revoke all on function public.claim_monetization_provider_rechecks(
  uuid, integer, integer
) from public, anon, authenticated, service_role;
revoke all on function public.finish_monetization_provider_recheck(
  bigint, uuid, timestamptz, text
) from public, anon, authenticated, service_role;
revoke all on function public.retry_monetization_provider_recheck(
  bigint, uuid, text, integer
) from public, anon, authenticated, service_role;
revoke all on function public.bind_verified_linked_purchase_token(
  text, text, text, timestamptz
) from public, anon, authenticated, service_role;
revoke all on function public.bind_verified_purchase_token(
  text, uuid, text, timestamptz, text
) from public, anon, authenticated, service_role;
revoke all on function public.bind_verified_purchase_token(text, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.reconcile_google_play_subscription(
  text, text, text, boolean, boolean, text, timestamptz, timestamptz,
  text, jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.reconcile_google_play_voided_purchase(
  text, timestamptz, text, text, jsonb
) from public, anon, authenticated, service_role;

grant execute on function public.ensure_billing_principal(uuid)
  to service_role;
grant execute on function public.ensure_monetization_wallet_for_principal(uuid)
  to service_role;
grant execute on function public.reserve_ai_usage_for_principal(
  uuid, text, integer, text
) to service_role;
grant execute on function public.reserve_ai_usage(uuid, text, integer, text)
  to service_role;
grant execute on function public.settle_ai_usage_for_principal(
  uuid, text, boolean, integer, integer, text, text, jsonb
) to service_role;
grant execute on function public.settle_ai_usage(
  uuid, text, boolean, integer, integer, text, text, jsonb
) to service_role;
grant execute on function public.sync_monetization_wallet_authority(
  uuid, text, text, boolean, timestamptz, text
) to service_role;
grant execute on function public.apply_monetization_allowance_grant(
  uuid, text, text, text, text, integer, integer, timestamptz
) to service_role;
grant execute on function public.claim_monetization_provider_rechecks(
  uuid, integer, integer
) to service_role;
grant execute on function public.retry_monetization_provider_recheck(
  bigint, uuid, text, integer
) to service_role;
grant execute on function public.bind_verified_linked_purchase_token(
  text, text, text, timestamptz
) to service_role;
grant execute on function public.bind_verified_purchase_token(
  text, uuid, text, timestamptz, text
) to service_role;
grant execute on function public.bind_verified_purchase_token(text, uuid, text)
  to service_role;
grant execute on function public.reconcile_google_play_subscription(
  text, text, text, boolean, boolean, text, timestamptz, timestamptz,
  text, jsonb
) to service_role;
grant execute on function public.reconcile_google_play_voided_purchase(
  text, timestamptz, text, text, jsonb
) to service_role;

revoke all on function public.expire_stale_monetization_subscriptions()
  from public, anon, authenticated, service_role;
grant execute on function public.expire_stale_monetization_subscriptions()
  to service_role;
