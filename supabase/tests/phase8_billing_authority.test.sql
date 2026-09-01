begin;

create extension if not exists pgtap with schema extensions;
select plan(140);

select has_table(
  'public', 'billing_principals',
  'durable opaque billing principals exist'
);
select has_table(
  'public', 'monetization_allowance_grants',
  'paid allowance grant ledger exists'
);
select ok(
  to_regclass('public.monetization_allowance_grants_resubscribe_token_idx')
    is not null,
  'resubscribe grants are unique per successor token'
);
select ok(
  to_regclass('public.monetization_allowance_grants_resubscribe_lapse_idx')
    is not null,
  'resubscribe grants are unique per expired predecessor'
);
select ok(
  to_regclass('public.monetization_allowance_grants_recovery_period_idx')
    is not null,
  'recovery grants are unique per provider-confirmed paid period'
);
select has_table(
  'public', 'monetization_provider_recheck_queue',
  'provider recheck queue exists'
);

insert into auth.users (id, email) values
  ('80808080-8080-4080-8080-808080808080', 'phase8-original@example.invalid');

set local role service_role;

-- These fixtures are already-hashed values; no raw purchase token is stored.
select is(
  (public.bind_verified_purchase_token(
    repeat('a', 64), '80808080-8080-4080-8080-808080808080',
    'chronospark_premium_monthly', now(), null
  )->>'bound')::boolean,
  true,
  'verified initial token hash binds to the auth account'
);
select ok(
  (select billing_principal_id <> current_user_id
   from public.billing_principals
   where current_user_id = '80808080-8080-4080-8080-808080808080'),
  'billing principal is an opaque UUID distinct from the auth user ID'
);

select is(
  (public.reconcile_google_play_subscription(
    repeat('a', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-order-initial', now() + interval '30 days', now(),
    'phase8:verify:initial',
    jsonb_build_object('source', 'client_verification')
  )->>'applied')::boolean,
  true,
  'verified initial paid activation applies'
);
select results_eq(
  $$select grant_cause, notification_type, credits
    from public.monetization_allowance_grants
    where billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('a', 64)
    )$$,
  $$values ('initial_activation'::text, null::integer, 300)$$,
  'initial paid activation records exactly one causal 300-credit grant'
);
select results_eq(
  $$select balance, allowance_remaining, period_credits, tier
    from public.monetization_wallets
    where user_id = '80808080-8080-4080-8080-808080808080'$$,
  $$values (300, 300, 300, 'premium_monthly'::text)$$,
  'initial paid activation fills the monthly allowance once'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('a', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-order-initial', now() + interval '30 days', now(),
    'phase8:verify:initial',
    jsonb_build_object('source', 'client_verification')
  )->>'duplicate')::boolean,
  true,
  'initial activation event replay is idempotent'
);
select is(
  (select count(*)::integer
   from public.monetization_allowance_grants
   where billing_principal_id = (
     select billing_principal_id from public.purchase_bindings
     where token_hash = repeat('a', 64)
   )),
  1,
  'initial activation replay creates no second grant'
);

reset role;
insert into auth.users (id, email) values
  ('83838383-8383-4383-8383-838383838383', 'phase8-annual@example.invalid');
set local role service_role;
select is(
  (public.bind_verified_purchase_token(
    repeat('3', 64), '83838383-8383-4383-8383-838383838383',
    'chronospark_premium_annual', now(), null
  )->>'bound')::boolean,
  true,
  'verified annual token binds to its auth account'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('3', 64), 'chronospark_premium_annual', 'active', true, true,
    'phase8-order-annual', now() + interval '365 days', now(),
    'phase8:verify:annual',
    jsonb_build_object('source', 'client_verification')
  )->>'applied')::boolean,
  true,
  'verified annual activation applies through the same authority path'
);
select results_eq(
  $$select balance, allowance_remaining, period_credits, tier
    from public.monetization_wallets
    where user_id = '83838383-8383-4383-8383-838383838383'$$,
  $$values (360, 360, 360, 'premium_yearly'::text)$$,
  'annual authority fills exactly the supported 360-credit allowance'
);
select results_eq(
  $$select grant_cause, credits
    from public.monetization_allowance_grants
    where billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('3', 64)
    )$$,
  $$values ('initial_activation'::text, 360)$$,
  'annual activation records one causal 360-credit grant'
);

select is(
  (public.reserve_ai_usage(
    '80808080-8080-4080-8080-808080808080',
    'phase8-completed-ai-request', 3, repeat('c', 64)
  )->>'allowed')::boolean,
  true,
  'completed AI fixture reserves three paid allowance credits'
);
select is(
  public.settle_ai_usage(
    '80808080-8080-4080-8080-808080808080',
    'phase8-completed-ai-request', true, 12, 24,
    'fixture-provider-request', null,
    jsonb_build_object('fixture', 'response metadata')
  )->>'state',
  'completed',
  'completed AI fixture stores provider response metadata before detachment'
);
select ok(
  (select provider_request_id is not null
      and response_payload <> '{}'::jsonb
   from public.ai_usage_requests
   where request_key = 'phase8-completed-ai-request'),
  'completed AI response metadata exists before auth deletion'
);

insert into public.planner_explanation_quotes (
  user_id, request_key, quote_fingerprint, input_fingerprint,
  expected_credits, model_id, model_label, prompt_version,
  response_schema_version, disclosure_version, expires_at
) values (
  '80808080-8080-4080-8080-808080808080',
  'phase8-completed-ai-request', repeat('d', 64), repeat('e', 64),
  3, 'fixture-model', 'Fixture model', 'phase8-fixture', 1, 1,
  now() + interval '4 minutes'
);
insert into public.planner_explanation_replays (
  user_id, request_key, response_payload, content_expires_at
) values (
  '80808080-8080-4080-8080-808080808080',
  'phase8-completed-ai-request',
  jsonb_build_object('fixture', 'planner replay'),
  now() + interval '3 minutes'
);
select is(
  (select count(*)::integer
   from public.planner_explanation_replays
   where user_id = '80808080-8080-4080-8080-808080808080'),
  1,
  'Planner replay fixture exists before auth deletion'
);

select is(
  (public.reconcile_google_play_subscription(
    repeat('a', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-order-initial', now() + interval '31 days',
    now() + interval '1 hour', 'phase8:rtdn:type9-extension',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 9
    )
  )->>'creditsGranted')::integer,
  0,
  'RTDN type 9 expiry extension grants no credits'
);
select results_eq(
  $$select balance, allowance_remaining
    from public.monetization_wallets
    where user_id = '80808080-8080-4080-8080-808080808080'$$,
  $$values (297, 297)$$,
  'RTDN type 9 preserves the spent paid allowance'
);
select is(
  (select count(*)::integer
   from public.monetization_allowance_grants
   where billing_principal_id = (
     select billing_principal_id from public.purchase_bindings
     where token_hash = repeat('a', 64)
   )),
  1,
  'RTDN type 9 records no allowance grant'
);

select is(
  public.reconcile_google_play_subscription(
    repeat('a', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-order-initial', now() + interval '32 days',
    now() + interval '2 hours', 'phase8:rtdn:type2-reused-order',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 2
    )
  )->>'allowanceGrantReason',
  'duplicate_order_id',
  'RTDN type 2 with a reused order cannot refill allowance'
);
select results_eq(
  $$select balance, allowance_remaining
    from public.monetization_wallets
    where user_id = '80808080-8080-4080-8080-808080808080'$$,
  $$values (297, 297)$$,
  'reused verified order preserves the spent balance'
);

select is(
  (public.reconcile_google_play_subscription(
    repeat('a', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-order-renewal', now() + interval '60 days',
    now() + interval '3 hours', 'phase8:rtdn:type2-new-order',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 2
    )
  )->>'renewed')::boolean,
  true,
  'RTDN type 2 with a new verified order grants renewal allowance'
);
select results_eq(
  $$select grant_cause, notification_type, credits
    from public.monetization_allowance_grants
    where grant_cause = 'rtdn_renewal'
      and billing_principal_id = (
        select billing_principal_id from public.purchase_bindings
        where token_hash = repeat('a', 64)
      )$$,
  $$values ('rtdn_renewal'::text, 2, 300)$$,
  'renewal ledger ties the refill to RTDN type 2'
);
select results_eq(
  $$select balance, allowance_remaining
    from public.monetization_wallets
    where user_id = '80808080-8080-4080-8080-808080808080'$$,
  $$values (300, 300)$$,
  'new verified renewal order refills the monthly allowance'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('a', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-order-renewal', now() + interval '60 days',
    now() + interval '3 hours', 'phase8:rtdn:type2-new-order',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 2
    )
  )->>'duplicate')::boolean,
  true,
  'renewal event replay is idempotent'
);
select is(
  public.reconcile_google_play_subscription(
    repeat('a', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-order-renewal', now() + interval '61 days',
    now() + interval '4 hours', 'phase8:rtdn:type2-duplicate-order',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 2
    )
  )->>'allowanceGrantReason',
  'duplicate_order_id',
  'new event with the same verified order is grant-idempotent'
);
select results_eq(
  $$select count(*)::integer, max(balance)
    from public.monetization_allowance_grants grants
    join public.monetization_wallets wallet using (billing_principal_id)
    where grants.billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('a', 64)
    )$$,
  $$values (2, 300)$$,
  'duplicate event and order leave two grants and one full allowance'
);

select is(
  (public.bind_verified_linked_purchase_token(
    repeat('b', 64), repeat('a', 64),
    'chronospark_premium_monthly', now() + interval '5 hours'
  )->>'bound')::boolean,
  true,
  'verified linked successor token hash binds'
);
select results_eq(
  $$select count(*)::integer,
      count(distinct billing_principal_id)::integer
    from public.purchase_bindings
    where token_hash in (repeat('a', 64), repeat('b', 64))$$,
  $$values (2, 1)$$,
  'linked successor retains the original billing principal'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('b', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-order-renewal', now() + interval '90 days',
    now() + interval '5 hours', 'phase8:verify:successor',
    jsonb_build_object('source', 'client_verification')
  )->>'applied')::boolean,
  true,
  'verified successor becomes authoritative without another grant'
);
select results_eq(
  $$select is_active, purchase_token_hash, balance
    from public.monetization_subscription_statuses status
    join public.monetization_wallets wallet using (billing_principal_id)
    where status.purchase_token_hash = repeat('b', 64)$$,
  $$values (true, repeat('b', 64), 300)$$,
  'successor authority keeps the principal wallet and balance'
);
select is(
  (select count(*)::integer
   from public.monetization_allowance_grants
   where billing_principal_id = (
     select billing_principal_id from public.purchase_bindings
     where token_hash = repeat('b', 64)
   )),
  2,
  'successor verification creates no allowance grant'
);
select is(
  public.reconcile_google_play_subscription(
    repeat('a', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-order-old-replay', now() + interval '120 days',
    now() + interval '6 hours', 'phase8:rtdn:old-token-active',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 2
    )
  )->>'reason',
  'old_token',
  'old linked token cannot replace its successor'
);
select results_eq(
  $$select status.purchase_token_hash, status.is_active, wallet.balance
    from public.monetization_subscription_statuses status
    join public.monetization_wallets wallet using (billing_principal_id)
    where status.billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('b', 64)
    )$$,
  $$values (repeat('b', 64), true, 300)$$,
  'old-token replay preserves successor authority and balance'
);
select is(
  (select count(*)::integer
   from public.monetization_allowance_grants
   where billing_principal_id = (
     select billing_principal_id from public.purchase_bindings
     where token_hash = repeat('b', 64)
   )),
  2,
  'old-token replay cannot mint a renewal grant'
);

update public.monetization_subscription_statuses
set expires_at = now() - interval '5 minutes'
where purchase_token_hash = repeat('b', 64);

select is(
  public.expire_stale_monetization_subscriptions(),
  1,
  'local expiry queues one provider recheck'
);
select results_eq(
  $$select status, is_active, purchase_token_hash
    from public.monetization_subscription_statuses
    where purchase_token_hash = repeat('b', 64)$$,
  $$values ('active'::text, true, repeat('b', 64))$$,
  'local expiry does not revoke provider authority'
);
select results_eq(
  $$select state, reason, reconciled_at is null
    from public.monetization_provider_recheck_queue
    where purchase_token_hash = repeat('b', 64)$$,
  $$values ('pending'::text, 'stored_expiry_due'::text, true)$$,
  'local expiry leaves a pending unresolved provider recheck'
);
select is(
  public.expire_stale_monetization_subscriptions(),
  0,
  'duplicate local expiry scan does not duplicate the queue item'
);

select is(
  (public.reconcile_google_play_subscription(
    repeat('b', 64), 'chronospark_premium_monthly', 'expired', false, false,
    'phase8-order-renewal', now() - interval '5 minutes',
    now() + interval '7 hours', 'phase8:rtdn:provider-expired',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 13
    )
  )->>'applied')::boolean,
  true,
  'provider-confirmed expiry reconciles inactive authority'
);
select results_eq(
  $$select status, is_active from public.monetization_subscription_statuses
    where purchase_token_hash = repeat('b', 64)$$,
  $$values ('expired'::text, false)$$,
  'provider-confirmed expiry revokes active subscription status'
);
select results_eq(
  $$select state, resolution, reconciled_at is not null
    from public.monetization_provider_recheck_queue
    where purchase_token_hash = repeat('b', 64)$$,
  $$values ('reconciled'::text, 'expired'::text, true)$$,
  'provider-confirmed expiry completes the queued recheck'
);
select results_eq(
  $$select balance, allowance_remaining, tier
    from public.monetization_wallets
    where billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('b', 64)
    )$$,
  $$values (20, 20, 'free'::text)$$,
  'provider-confirmed expiry reduces the wallet to free authority'
);

select is(
  (public.reconcile_google_play_voided_purchase(
    repeat('b', 64), now() + interval '8 hours',
    'phase8:voided:successor', 'phase8-order-renewal',
    jsonb_build_object('source', 'voided_purchase_fixture')
  )->>'applied')::boolean,
  true,
  'provider voided purchase makes successor authority terminal'
);
select results_eq(
  $$select status.status, status.is_active, purchase.purchase_state
    from public.monetization_subscription_statuses status
    join public.monetization_purchases purchase
      on purchase.purchase_token_hash = status.purchase_token_hash
    where status.purchase_token_hash = repeat('b', 64)$$,
  $$values ('revoked'::text, false, 'refunded'::text)$$,
  'voided purchase stores terminal revoked and refunded state'
);
select is(
  public.reconcile_google_play_subscription(
    repeat('b', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-order-late-active', now() + interval '120 days',
    now() + interval '9 hours', 'phase8:rtdn:late-active-after-void',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 2
    )
  )->>'reason',
  'terminal_token',
  'late active replay cannot reverse voided authority'
);
select results_eq(
  $$select status.status, status.is_active, wallet.balance
    from public.monetization_subscription_statuses status
    join public.monetization_wallets wallet using (billing_principal_id)
    where status.purchase_token_hash = repeat('b', 64)$$,
  $$values ('revoked'::text, false, 20)$$,
  'terminal replay preserves revoked status and free balance'
);
select is(
  (select count(*)::integer
   from public.monetization_allowance_grants
   where billing_principal_id = (
     select billing_principal_id from public.purchase_bindings
     where token_hash = repeat('b', 64)
   )),
  2,
  'terminal replay cannot mint a late allowance grant'
);

select is(
  (public.reserve_ai_usage(
    '80808080-8080-4080-8080-808080808080',
    'phase8-stale-ai-request', 2, repeat('f', 64)
  )->>'allowed')::boolean,
  true,
  'stale AI fixture reserves credit before account detachment'
);
update public.ai_usage_requests
set created_at = now() - interval '20 minutes'
where request_key = 'phase8-stale-ai-request';
select results_eq(
  $$select state, balance
    from public.ai_usage_requests usage
    join public.monetization_wallets wallet using (billing_principal_id)
    where usage.request_key = 'phase8-stale-ai-request'$$,
  $$values ('reserved'::text, 18)$$,
  'stale reservation remains charged before detachment cleanup'
);

reset role;
delete from auth.users
where id = '80808080-8080-4080-8080-808080808080';

select results_eq(
  $$select current_user_id is null, retired_at is null
    from public.billing_principals
    where billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('b', 64)
    )$$,
  $$values (true, true)$$,
  'auth deletion detaches without retiring the billing principal'
);
select ok(
  (select not exists (
      select 1 from public.purchase_bindings
      where billing_principal_id = principal.billing_principal_id
        and user_id is not null
    ) and not exists (
      select 1 from public.monetization_subscription_statuses
      where billing_principal_id = principal.billing_principal_id
        and user_id is not null
    ) and not exists (
      select 1 from public.monetization_wallets
      where billing_principal_id = principal.billing_principal_id
        and user_id is not null
    ) and not exists (
      select 1 from public.monetization_credit_transactions
      where billing_principal_id = principal.billing_principal_id
        and user_id is not null
    ) and not exists (
      select 1 from public.monetization_purchases
      where billing_principal_id = principal.billing_principal_id
        and user_id is not null
    ) and not exists (
      select 1 from public.monetization_entitlement_events
      where billing_principal_id = principal.billing_principal_id
        and user_id is not null
    ) and not exists (
      select 1 from public.ai_usage_requests
      where billing_principal_id = principal.billing_principal_id
        and user_id is not null
    )
   from public.billing_principals principal
   where principal.billing_principal_id = (
     select billing_principal_id from public.purchase_bindings
     where token_hash = repeat('b', 64)
   )),
  'auth deletion detaches user IDs from all principal-owned billing rows'
);
select results_eq(
  $$select count(*)::integer,
      count(distinct billing_principal_id)::integer,
      bool_or(
        token_hash = repeat('b', 64)
        and predecessor_token_hash = repeat('a', 64)
      )
    from public.purchase_bindings
    where token_hash in (repeat('a', 64), repeat('b', 64))$$,
  $$values (2, 1, true)$$,
  'auth deletion preserves hashed predecessor lineage on one principal'
);
select results_eq(
  $$select user_id is null, balance
    from public.monetization_wallets
    where billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('b', 64)
    )$$,
  $$values (true, 18)$$,
  'auth deletion preserves the detached wallet and charged balance'
);
select is(
  (select count(*)::integer
   from public.monetization_allowance_grants
   where billing_principal_id = (
     select billing_principal_id from public.purchase_bindings
     where token_hash = repeat('b', 64)
   )),
  2,
  'auth deletion preserves the causal allowance grant ledger'
);
select results_eq(
  $$select
      (select count(*) from public.planner_explanation_replays
       where user_id = '80808080-8080-4080-8080-808080808080'),
      (select count(*) from public.planner_explanation_quotes
       where user_id = '80808080-8080-4080-8080-808080808080')$$,
  $$values (0::bigint, 0::bigint)$$,
  'auth deletion removes Planner replay and quote content'
);
select results_eq(
  $$select state, user_id is null, provider_request_id is null,
      response_payload = '{}'::jsonb
    from public.ai_usage_requests
    where request_key = 'phase8-completed-ai-request'$$,
  $$values ('completed'::text, true, true, true)$$,
  'auth deletion scrubs completed AI response metadata'
);
select results_eq(
  $$select state, user_id is null
    from public.ai_usage_requests
    where request_key = 'phase8-stale-ai-request'$$,
  $$values ('reserved'::text, true)$$,
  'stale AI reservation remains principal-owned after user detachment'
);

set local role service_role;
select is(
  public.refund_stale_ai_usage_reservations(interval '10 minutes'),
  1,
  'stale reserved AI credit refunds after account detachment'
);
select results_eq(
  $$select state, failure_code, user_id is null,
      provider_request_id is null, response_payload = '{}'::jsonb
    from public.ai_usage_requests
    where request_key = 'phase8-stale-ai-request'$$,
  $$values ('refunded'::text, 'reservation_timeout'::text, true, true, true)$$,
  'detached stale reservation settles as a scrubbed timeout refund'
);
select results_eq(
  $$select user_id is null, balance
    from public.monetization_wallets
    where billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('b', 64)
    )$$,
  $$values (true, 20)$$,
  'detached stale refund restores the preserved wallet balance'
);
select is(
  (select count(*)::integer
   from public.monetization_credit_transactions
   where type = 'refund'
     and metadata->>'request_key' = 'phase8-stale-ai-request'
     and user_id is null),
  1,
  'detached stale refund appends one principal-owned ledger entry'
);
select is(
  public.refund_stale_ai_usage_reservations(interval '10 minutes'),
  0,
  'stale refund maintenance replay is idempotent'
);

reset role;
insert into auth.users (id, email) values
  ('81818181-8181-4181-8181-818181818181', 'phase8-recreated@example.invalid');
set local role service_role;

select is(
  (public.reserve_ai_usage(
    '81818181-8181-4181-8181-818181818181',
    'phase8-recreated-free-request', 1, repeat('9', 64)
  )->>'allowed')::boolean,
  true,
  'recreated account can spend one free credit before purchase restore'
);
select is(
  public.settle_ai_usage(
    '81818181-8181-4181-8181-818181818181',
    'phase8-recreated-free-request', true, 4, 8,
    'phase8-recreated-provider-request', null,
    jsonb_build_object('fixture', 'free bootstrap response')
  )->>'state',
  'completed',
  'recreated account free-credit request completes before purchase restore'
);
select is(
  (public.reserve_ai_usage(
    '81818181-8181-4181-8181-818181818181',
    'phase8-recreated-reserved-request', 1, repeat('0', 64)
  )->>'allowed')::boolean,
  true,
  'recreated account can have an in-flight free request before restore'
);
select is(
  (public.bind_verified_purchase_token(
    repeat('b', 64), '81818181-8181-4181-8181-818181818181',
    'chronospark_premium_monthly', now() + interval '10 hours', null
  )->>'bound')::boolean,
  true,
  'verified successor token reattaches a recreated auth account'
);
select results_eq(
  $$select principal.current_user_id is null,
      principal.retired_at is not null,
      usage.user_id is null,
      usage.provider_request_id is null,
      usage.response_payload = '{}'::jsonb
    from public.ai_usage_requests usage
    join public.billing_principals principal using (billing_principal_id)
    where usage.request_key = 'phase8-recreated-free-request'$$,
  $$values (true, true, true, true, true)$$,
  'free-only bootstrap principal retires and scrubs AI response data'
);
select results_eq(
  $$select state, failure_code, user_id is null,
      provider_request_id is null, response_payload = '{}'::jsonb
    from public.ai_usage_requests
    where request_key = 'phase8-recreated-reserved-request'$$,
  $$values (
      'refunded'::text, 'principal_reattached'::text, true, true, true
    )$$,
  'reattachment refunds and scrubs an in-flight free reservation'
);
select results_eq(
  $$select principal.current_user_id, binding.billing_principal_id =
      principal.billing_principal_id
    from public.billing_principals principal
    join public.purchase_bindings binding using (billing_principal_id)
    where binding.token_hash = repeat('b', 64)$$,
  $$values ('81818181-8181-4181-8181-818181818181'::uuid, true)$$,
  'verified reattachment restores the same durable principal'
);
select results_eq(
  $$select user_id, balance
    from public.monetization_wallets
    where user_id = '81818181-8181-4181-8181-818181818181'$$,
  $$values ('81818181-8181-4181-8181-818181818181'::uuid, 20)$$,
  'verified reattachment restores the same preserved wallet balance'
);
select results_eq(
  $$select count(*)::integer,
      count(distinct billing_principal_id)::integer,
      bool_and(user_id = '81818181-8181-4181-8181-818181818181'::uuid)
    from public.purchase_bindings
    where token_hash in (repeat('a', 64), repeat('b', 64))$$,
  $$values (2, 1, true)$$,
  'verified reattachment reconnects both hashed lineage rows'
);
select is(
  (select count(*)::integer
   from public.monetization_allowance_grants
   where billing_principal_id = (
     select billing_principal_id from public.purchase_bindings
     where token_hash = repeat('b', 64)
   )),
  2,
  'verified reattachment creates no new allowance grant'
);
select is(
  (public.reserve_ai_usage(
    '81818181-8181-4181-8181-818181818181',
    'phase8-completed-ai-request', 3, repeat('c', 64)
  )->>'duplicate')::boolean,
  true,
  'AI idempotency remains bound to the durable principal after recreation'
);
select results_eq(
  $$select balance from public.monetization_wallets
    where user_id = '81818181-8181-4181-8181-818181818181'$$,
  $$values (20)$$,
  'principal-scoped AI replay does not debit the reattached wallet'
);

reset role;
insert into auth.users (id, email) values
  ('86868686-8686-4686-8686-868686868686', 'phase8-resubscribe@example.invalid');
set local role service_role;

select is(
  (public.bind_verified_purchase_token(
    repeat('d', 64), '86868686-8686-4686-8686-868686868686',
    'chronospark_premium_monthly', now() + interval '11 hours', null
  )->>'bound')::boolean,
  true,
  'lapsed-resubscribe fixture binds its original purchase token'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('d', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-resubscribe-original-order', now() + interval '30 days',
    now() + interval '11 hours', 'phase8:verify:resubscribe-original',
    jsonb_build_object('source', 'client_verification')
  )->>'creditsGranted')::integer,
  300,
  'original paid period receives one monthly allowance'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('d', 64), 'chronospark_premium_monthly', 'expired', false, false,
    'phase8-resubscribe-original-order', now() - interval '1 minute',
    now() + interval '12 hours', 'phase8:rtdn:resubscribe-expired',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 13
    )
  )->>'applied')::boolean,
  true,
  'provider expiry closes the original paid period'
);
select is(
  (public.bind_verified_linked_purchase_token(
    repeat('e', 64), repeat('d', 64),
    'chronospark_premium_monthly', now() + interval '13 hours'
  )->>'bound')::boolean,
  true,
  'out-of-app successor binds to the expired durable principal'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('e', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-resubscribe-new-order', now() + interval '31 days',
    now() + interval '13 hours', 'phase8:rtdn:resubscribe-purchased',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 4,
      'lineageSource', 'out_of_app_resubscribe'
    )
  )->>'creditsGranted')::integer,
  300,
  'lapsed subscriptions-center purchase refills the paid allowance once'
);
select results_eq(
  $$select grant_cause, notification_type, order_id
    from public.monetization_allowance_grants
    where purchase_token_hash = repeat('e', 64)$$,
  $$values (
      'resubscription_activation'::text, 4,
      'phase8-resubscribe-new-order'::text
    )$$,
  'resubscribe grant records its distinct provider cause and order'
);
select results_eq(
  $$select status.purchase_token_hash, status.is_active, wallet.balance
    from public.monetization_subscription_statuses status
    join public.monetization_wallets wallet using (billing_principal_id)
    where status.purchase_token_hash = repeat('e', 64)$$,
  $$values (repeat('e', 64), true, 300)$$,
  'resubscribe activates the successor and restores monthly allowance'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('e', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-resubscribe-new-order', now() + interval '31 days',
    now() + interval '13 hours', 'phase8:rtdn:resubscribe-purchased',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 4,
      'lineageSource', 'out_of_app_resubscribe'
    )
  )->>'duplicate')::boolean,
  true,
  'resubscribe event replay is idempotent'
);
select is(
  (select count(*)::integer
   from public.monetization_allowance_grants
   where billing_principal_id = (
     select billing_principal_id from public.purchase_bindings
     where token_hash = repeat('e', 64)
   )),
  2,
  'resubscribe replay leaves exactly one grant per paid period'
);
select is(
  (public.bind_verified_linked_purchase_token(
    repeat('f', 64), repeat('e', 64),
    'chronospark_premium_annual', now() + interval '14 hours'
  )->>'bound')::boolean,
  true,
  'active in-app replacement binds to the same principal'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('f', 64), 'chronospark_premium_annual', 'active', true, true,
    'phase8-active-replacement-order', now() + interval '365 days',
    now() + interval '14 hours', 'phase8:verify:active-replacement',
    jsonb_build_object(
      'source', 'client_verification', 'lineageSource', 'linked_purchase'
    )
  )->>'creditsGranted')::integer,
  0,
  'active linked replacement does not imitate a lapsed resubscription grant'
);
select results_eq(
  $$select count(*)::integer, max(wallet.balance)
    from public.monetization_allowance_grants grants
    join public.monetization_wallets wallet using (billing_principal_id)
    where grants.billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('f', 64)
    )$$,
  $$values (2, 300)$$,
  'active replacement preserves prior allowance and grant count'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('f', 64), 'chronospark_premium_annual', 'active', true, true,
    'phase8-active-replacement-renewal-order', now() + interval '730 days',
    now() + interval '15 hours', 'phase8:rtdn:replacement-renewal',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 2
    )
  )->>'creditsGranted')::integer,
  360,
  'legitimate later renewal still refills the active annual successor'
);
select results_eq(
  $$select count(*)::integer, max(wallet.balance)
    from public.monetization_allowance_grants grants
    join public.monetization_wallets wallet using (billing_principal_id)
    where grants.billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('f', 64)
    )$$,
  $$values (3, 360)$$,
  'later renewal adds one causal grant and the annual allowance'
);

reset role;
insert into auth.users (id, email) values
  ('85858585-8585-4585-8585-858585858585', 'phase8-late-expiry@example.invalid');
set local role service_role;
select is(
  (public.bind_verified_purchase_token(
    repeat('4', 64), '85858585-8585-4585-8585-858585858585',
    'chronospark_premium_monthly', now() + interval '18 hours', null
  )->>'bound')::boolean,
  true,
  'late-expiry fixture binds its original purchase token'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('4', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-late-expiry-original-order', now() + interval '19 hours',
    now() + interval '18 hours', 'phase8:verify:late-expiry-original',
    jsonb_build_object('source', 'client_verification')
  )->>'creditsGranted')::integer,
  300,
  'late-expiry fixture starts with one paid allowance'
);
select is(
  (public.bind_verified_linked_purchase_token(
    repeat('5', 64), repeat('4', 64),
    'chronospark_premium_monthly', now() + interval '20 hours'
  )->>'bound')::boolean,
  true,
  'successor binds before the delayed predecessor expiry arrives'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('5', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-late-expiry-successor-order', now() + interval '50 hours',
    now() + interval '20 hours', 'phase8:rtdn:late-expiry-successor',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 4,
      'lineageSource', 'out_of_app_resubscribe'
    )
  )->>'creditsGranted')::integer,
  0,
  'successor-first processing waits for provider-confirmed predecessor expiry'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('4', 64), 'chronospark_premium_monthly', 'expired', false, false,
    'phase8-late-expiry-original-order', now() + interval '19 hours',
    now() + interval '21 hours', 'phase8:rtdn:late-expiry-delayed',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 13
    )
  )->>'creditsGranted')::integer,
  300,
  'delayed provider expiry completes the successor allowance exactly once'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('4', 64), 'chronospark_premium_monthly', 'expired', false, false,
    'phase8-late-expiry-original-order', now() + interval '19 hours',
    now() + interval '21 hours', 'phase8:rtdn:late-expiry-delayed',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 13
    )
  )->>'creditsGranted')::integer,
  0,
  'delayed provider expiry replay cannot duplicate the successor allowance'
);
select results_eq(
  $$select grant_cause, notification_type, order_id
    from public.monetization_allowance_grants
    where purchase_token_hash = repeat('5', 64)$$,
  $$values (
      'resubscription_activation'::text, 4,
      'phase8-late-expiry-successor-order'::text
    )$$,
  'late expiry records one causal grant against the successor purchase'
);
select results_eq(
  $$select status.purchase_token_hash, status.is_active, wallet.balance
    from public.monetization_subscription_statuses status
    join public.monetization_wallets wallet using (billing_principal_id)
    where status.billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('5', 64)
    )$$,
  $$values (repeat('5', 64), true, 300)$$,
  'late predecessor expiry preserves active successor authority and allowance'
);

reset role;
insert into auth.users (id, email) values
  ('89898989-8989-4989-8989-898989898989', 'phase8-hold-recovery@example.invalid');
set local role service_role;
select is(
  (public.bind_verified_purchase_token(
    repeat('6', 64), '89898989-8989-4989-8989-898989898989',
    'chronospark_premium_monthly', now() + interval '22 hours', null
  )->>'bound')::boolean,
  true,
  'account-hold recovery fixture binds its purchase token'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('6', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-hold-original-order', now() + interval '30 days',
    now() + interval '22 hours', 'phase8:verify:hold-original',
    jsonb_build_object('source', 'client_verification')
  )->>'creditsGranted')::integer,
  300,
  'account-hold fixture starts with one paid allowance'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('6', 64), 'chronospark_premium_monthly', 'on_hold', false, false,
    'phase8-hold-original-order', now() + interval '30 days',
    now() + interval '23 hours', 'phase8:rtdn:hold-entered',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 5
    )
  )->>'applied')::boolean,
  true,
  'account hold removes paid authority'
);
select results_eq(
  $$select status.status, status.is_active, wallet.balance,
      wallet.allowance_remaining
    from public.monetization_subscription_statuses status
    join public.monetization_wallets wallet using (billing_principal_id)
    where status.purchase_token_hash = repeat('6', 64)$$,
  $$values ('on_hold'::text, false, 20, 20)$$,
  'account hold caps the wallet to the free allowance'
);
select results_eq(
  $$select (result->>'recovered')::boolean,
      (result->>'creditsGranted')::integer
    from (select public.reconcile_google_play_subscription(
      repeat('6', 64), 'chronospark_premium_monthly', 'active', true, true,
      'phase8-hold-recovery-order', now() + interval '60 days',
      now() + interval '24 hours', 'phase8:rtdn:hold-recovered',
      jsonb_build_object(
        'source', 'google_play_rtdn', 'notificationType', 1
      )
    ) as result) recovered$$,
  $$values (true, 300)$$,
  'RTDN recovered authority restores one paid allowance'
);
select results_eq(
  $$select grant_cause, notification_type, order_id
    from public.monetization_allowance_grants
    where purchase_token_hash = repeat('6', 64)
      and grant_cause = 'recovery_activation'$$,
  $$values (
      'recovery_activation'::text, 1,
      'phase8-hold-recovery-order'::text
    )$$,
  'same-token recovery records an explicit provider cause and order'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('6', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-hold-recovery-order', now() + interval '60 days',
    now() + interval '24 hours', 'phase8:rtdn:hold-recovered',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 1
    )
  )->>'creditsGranted')::integer,
  0,
  'same-token recovery replay cannot duplicate allowance'
);
select results_eq(
  $$select count(*)::integer, max(wallet.balance), bool_and(status.is_active)
    from public.monetization_allowance_grants grants
    join public.monetization_wallets wallet using (billing_principal_id)
    join public.monetization_subscription_statuses status
      using (billing_principal_id)
    where grants.billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('6', 64)
    )$$,
  $$values (2, 300, true)$$,
  'same-token recovery leaves one grant per paid period and active authority'
);

reset role;
insert into auth.users (id, email) values
  ('90909090-9090-4090-8090-909090909090', 'phase8-hold-repurchase@example.invalid');
set local role service_role;
select is(
  (public.bind_verified_purchase_token(
    repeat('7', 64), '90909090-9090-4090-8090-909090909090',
    'chronospark_premium_monthly', now() + interval '25 hours', null
  )->>'bound')::boolean,
  true,
  'account-hold repurchase fixture binds its original token'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('7', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-hold-repurchase-original-order', now() + interval '30 days',
    now() + interval '25 hours', 'phase8:verify:hold-repurchase-original',
    jsonb_build_object('source', 'client_verification')
  )->>'creditsGranted')::integer,
  300,
  'account-hold repurchase fixture starts with one paid allowance'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('7', 64), 'chronospark_premium_monthly', 'on_hold', false, false,
    'phase8-hold-repurchase-original-order', now() + interval '30 days',
    now() + interval '26 hours', 'phase8:rtdn:hold-repurchase-entered',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 5
    )
  )->>'applied')::boolean,
  true,
  'account hold removes authority before subscriptions-center repurchase'
);
select is(
  (public.bind_verified_linked_purchase_token(
    repeat('8', 64), repeat('7', 64),
    'chronospark_premium_monthly', now() + interval '27 hours'
  )->>'bound')::boolean,
  true,
  'account-hold repurchase successor binds to the same durable principal'
);
select results_eq(
  $$select (result->>'recovered')::boolean,
      (result->>'creditsGranted')::integer
    from (select public.reconcile_google_play_subscription(
      repeat('8', 64), 'chronospark_premium_monthly', 'active', true, true,
      'phase8-hold-repurchase-new-order', now() + interval '60 days',
      now() + interval '27 hours', 'phase8:rtdn:hold-repurchase-purchased',
      jsonb_build_object(
        'source', 'google_play_rtdn', 'notificationType', 4,
        'lineageSource', 'out_of_app_hold_repurchase'
      )
    ) as result) recovered$$,
  $$values (true, 300)$$,
  'subscriptions-center hold repurchase restores one paid allowance'
);
select results_eq(
  $$select grant_cause, notification_type, order_id,
      metadata->>'predecessorTokenHash'
    from public.monetization_allowance_grants
    where purchase_token_hash = repeat('8', 64)$$,
  $$values (
      'recovery_activation'::text, 4,
      'phase8-hold-repurchase-new-order'::text, repeat('7', 64)
    )$$,
  'hold repurchase grant records its provider cause, order, and lineage'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('8', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-hold-repurchase-new-order', now() + interval '60 days',
    now() + interval '27 hours', 'phase8:rtdn:hold-repurchase-purchased',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 4,
      'lineageSource', 'out_of_app_hold_repurchase'
    )
  )->>'creditsGranted')::integer,
  0,
  'hold repurchase replay cannot duplicate allowance'
);
select results_eq(
  $$select count(*)::integer, max(wallet.balance),
      max(status.purchase_token_hash)
    from public.monetization_allowance_grants grants
    join public.monetization_wallets wallet using (billing_principal_id)
    join public.monetization_subscription_statuses status
      using (billing_principal_id)
    where grants.billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('8', 64)
    )$$,
  $$values (2, 300, repeat('8', 64))$$,
  'hold repurchase leaves one grant per paid period on successor authority'
);

reset role;
insert into auth.users (id, email) values
  ('84848484-8484-4484-8484-848484848484', 'phase8-local-expiry@example.invalid');
set local role service_role;
select is(
  (public.bind_verified_purchase_token(
    repeat('1', 64), '84848484-8484-4484-8484-848484848484',
    'chronospark_premium_monthly', now() + interval '16 hours', null
  )->>'bound')::boolean,
  true,
  'local-expiry fixture binds its original token'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('1', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-local-expiry-original-order', now() + interval '30 days',
    now() + interval '16 hours', 'phase8:verify:local-expiry-original',
    jsonb_build_object('source', 'client_verification')
  )->>'creditsGranted')::integer,
  300,
  'local-expiry fixture starts with one paid allowance'
);
update public.monetization_subscription_statuses
set expires_at = now() - interval '1 minute'
where purchase_token_hash = repeat('1', 64);
select is(
  public.expire_stale_monetization_subscriptions(),
  1,
  'local clock expiry queues but does not invent provider expiry authority'
);
select is(
  (public.bind_verified_linked_purchase_token(
    repeat('2', 64), repeat('1', 64),
    'chronospark_premium_monthly', now() + interval '17 hours'
  )->>'bound')::boolean,
  true,
  'local-expiry successor binds without changing provider truth'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('2', 64), 'chronospark_premium_monthly', 'active', true, true,
    'phase8-local-expiry-successor-order', now() + interval '31 days',
    now() + interval '17 hours', 'phase8:rtdn:local-expiry-purchased',
    jsonb_build_object(
      'source', 'google_play_rtdn', 'notificationType', 4,
      'lineageSource', 'out_of_app_resubscribe'
    )
  )->>'creditsGranted')::integer,
  0,
  'local-only expiry cannot mint a resubscription allowance'
);
select results_eq(
  $$select count(*)::integer, max(wallet.balance)
    from public.monetization_allowance_grants grants
    join public.monetization_wallets wallet using (billing_principal_id)
    where grants.billing_principal_id = (
      select billing_principal_id from public.purchase_bindings
      where token_hash = repeat('2', 64)
    )$$,
  $$values (1, 300)$$,
  'local-only expiry preserves the original grant and balance'
);

reset role;

select ok(
  not has_table_privilege(
    'authenticated', 'public.billing_principals', 'SELECT'
  ),
  'authenticated role cannot read opaque principal records'
);
select ok(
  not has_column_privilege(
    'authenticated', 'public.purchase_bindings', 'token_hash', 'SELECT'
  ) and not has_column_privilege(
    'authenticated', 'public.monetization_subscription_statuses',
    'purchase_token_hash', 'SELECT'
  ),
  'authenticated role has no purchase token hash column privileges'
);
select ok(
  not has_table_privilege(
    'authenticated', 'public.monetization_provider_recheck_queue', 'SELECT'
  ) and not has_table_privilege(
    'authenticated', 'public.monetization_allowance_grants', 'SELECT'
  ),
  'authenticated role cannot read recheck or grant ledgers'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.refund_stale_ai_usage_reservations(interval)', 'EXECUTE'
  ) and not has_function_privilege(
    'authenticated',
    'public.expire_stale_monetization_subscriptions()', 'EXECUTE'
  ) and not has_function_privilege(
    'authenticated',
    'public.complete_monetization_provider_rechecks(text,timestamptz,text)',
    'EXECUTE'
  ) and not has_function_privilege(
    'authenticated',
    'public.claim_monetization_provider_rechecks(uuid,integer,integer)',
    'EXECUTE'
  ) and not has_function_privilege(
    'authenticated',
    'public.finish_monetization_provider_recheck(bigint,uuid,timestamptz,text)',
    'EXECUTE'
  ) and not has_function_privilege(
    'authenticated',
    'public.retry_monetization_provider_recheck(bigint,uuid,text,integer)',
    'EXECUTE'
  ),
  'authenticated role cannot execute Phase 8 maintenance RPCs'
);
select ok(
  not has_function_privilege(
    'service_role',
    'public.complete_monetization_provider_rechecks(text,timestamptz,text)',
    'EXECUTE'
  ),
  'service role cannot arbitrarily complete provider rechecks'
);
select ok(
  not has_table_privilege(
    'anon', 'public.monetization_subscription_statuses', 'SELECT'
  ) and not has_table_privilege(
    'anon', 'public.monetization_wallets', 'SELECT'
  ) and not has_table_privilege(
    'anon', 'public.purchase_bindings', 'SELECT'
  ) and not has_function_privilege(
    'anon',
    'public.reconcile_google_play_subscription(text,text,text,boolean,boolean,text,timestamptz,timestamptz,text,jsonb)',
    'EXECUTE'
  ),
  'anonymous role has no billing authority read or reconciliation access'
);

set local role service_role;
select throws_ok(
  $$select public.complete_monetization_provider_rechecks(
      repeat('b', 64), now(), 'active'
    )$$,
  '42501', null,
  'service role cannot complete a provider recheck outside reconciliation'
);
reset role;

set local role authenticated;
set local request.jwt.claim.sub = '81818181-8181-4181-8181-818181818181';

select results_eq(
  $$select balance, tier from public.monetization_wallets$$,
  $$values (20, 'free'::text)$$,
  'reattached account reads only its limited wallet projection'
);
select throws_ok(
  $$select * from public.billing_principals$$,
  '42501', null,
  'authenticated account cannot select billing principals'
);
select throws_ok(
  $$select token_hash from public.purchase_bindings$$,
  '42501', null,
  'authenticated account cannot select purchase token hashes'
);
select throws_ok(
  $$select purchase_token_hash
    from public.monetization_subscription_statuses$$,
  '42501', null,
  'authenticated account cannot select subscription token hashes'
);
select throws_ok(
  $$select * from public.monetization_provider_recheck_queue$$,
  '42501', null,
  'authenticated account cannot select provider recheck queue rows'
);
select throws_ok(
  $$select * from public.monetization_allowance_grants$$,
  '42501', null,
  'authenticated account cannot select allowance grant ledger rows'
);
select throws_ok(
  $$select public.expire_stale_monetization_subscriptions()$$,
  '42501', null,
  'authenticated account cannot execute local expiry maintenance'
);
select throws_ok(
  $$select public.refund_stale_ai_usage_reservations(interval '10 minutes')$$,
  '42501', null,
  'authenticated account cannot execute stale AI refund maintenance'
);
select throws_ok(
  $$select * from public.claim_monetization_provider_rechecks(
      '82828282-8282-4282-8282-828282828282', 1, 30
    )$$,
  '42501', null,
  'authenticated account cannot claim provider recheck work'
);

reset role;
select * from finish();
rollback;
