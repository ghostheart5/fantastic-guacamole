begin;

create extension if not exists pgtap with schema extensions;
select plan(86);

select has_table('public', 'monetization_wallets', 'wallet table exists');
select has_table('public', 'monetization_credit_transactions', 'credit ledger exists');
select has_table('public', 'ai_usage_requests', 'AI reservation table exists');
select has_table('public', 'backend_rate_limits', 'durable rate table exists');
select has_column(
  'public', 'monetization_subscription_statuses', 'provider_event_time',
  'subscription authority preserves provider event time'
);
select has_column(
  'public', 'purchase_bindings', 'predecessor_token_hash',
  'purchase bindings preserve immutable predecessor lineage'
);
select ok(
  pg_get_functiondef(
    'public.bind_verified_purchase_token(text,uuid,text,timestamptz,text)'::regprocedure
  ) like '%pg_advisory_xact_lock%',
  'binding RPC serializes related token hashes before ownership checks'
);

insert into auth.users (id, email) values
  ('33333333-3333-4333-8333-333333333333', 'billing-a@example.invalid'),
  ('44444444-4444-4444-8444-444444444444', 'billing-b@example.invalid');

set local role service_role;

select is(
  (public.consume_backend_rate_limit(
    'test:user', repeat('a', 64), 1, 60
  )->>'allowed')::boolean,
  true,
  'first durable rate-limit request is allowed'
);
select is(
  (public.consume_backend_rate_limit(
    'test:user', repeat('a', 64), 1, 60
  )->>'allowed')::boolean,
  false,
  'rate limit persists across calls'
);

select is(
  (public.reserve_ai_usage(
    '33333333-3333-4333-8333-333333333333',
    'request-billing-0001', 1, repeat('b', 64)
  )->>'allowed')::boolean,
  true,
  'AI request reserves a server wallet credit'
);
select is(
  (public.reserve_ai_usage(
    '33333333-3333-4333-8333-333333333333',
    'request-billing-0001', 1, repeat('b', 64)
  )->>'duplicate')::boolean,
  true,
  'AI reservation replay is idempotent'
);
select is(
  public.reserve_ai_usage(
    '33333333-3333-4333-8333-333333333333',
    'request-billing-0001', 1, repeat('d', 64)
  )->>'reason',
  'idempotency_mismatch',
  'same request id cannot be replayed with a different prompt hash'
);
select is(
  public.reserve_ai_usage(
    '33333333-3333-4333-8333-333333333333',
    'request-billing-0001', 2, repeat('b', 64)
  )->>'reason',
  'idempotency_mismatch',
  'same request id cannot be replayed with a different credit amount'
);
select is(
  (public.settle_ai_usage(
    '33333333-3333-4333-8333-333333333333',
    'request-billing-0001', false, null, null, null, 'test_refund', '{}'::jsonb
  )->>'balance')::integer,
  20,
  'failed AI request atomically refunds its credit'
);
select is(
  (select count(*)::integer from public.monetization_credit_transactions
   where user_id = '33333333-3333-4333-8333-333333333333'),
  3,
  'append-only ledger records initialization, spend, and refund'
);

select lives_ok(
  $$select public.reserve_ai_usage(
    '33333333-3333-4333-8333-333333333333',
    'request-billing-stale', 1, repeat('e', 64)
  )$$,
  'a reservation can be created for scheduled stale cleanup'
);
update public.ai_usage_requests
set created_at = now() - interval '20 minutes'
where user_id = '33333333-3333-4333-8333-333333333333'
  and request_key = 'request-billing-stale';
select is(
  public.refund_stale_ai_usage_reservations(interval '10 minutes'),
  1,
  'scheduled stale-reservation function refunds one abandoned request'
);
select is(
  (select balance from public.monetization_wallets
   where user_id = '33333333-3333-4333-8333-333333333333'),
  20,
  'scheduled stale refund restores the wallet balance'
);
select is(
  (select count(*)::integer from public.monetization_credit_transactions
   where user_id = '33333333-3333-4333-8333-333333333333'),
  5,
  'scheduled stale refund appends spend and refund ledger entries'
);

select is(
  (public.bind_verified_purchase_token(
    repeat('c', 64), '33333333-3333-4333-8333-333333333333',
    'chronospark_premium_monthly'
  )->>'bound')::boolean,
  true,
  'verified purchase token binds to one account'
);
select is(
  (public.bind_verified_purchase_token(
    repeat('c', 64), '44444444-4444-4444-8444-444444444444',
    'chronospark_premium_monthly'
  )->>'bound')::boolean,
  false,
  'verified purchase token cannot be rebound to another account'
);
select throws_ok(
  $$update public.purchase_bindings
    set user_id = user_id
    where token_hash = repeat('c', 64)$$,
  '42501',
  null,
  'service role cannot directly mutate the immutable binding tuple'
);
update public.purchase_bindings
set created_at = now() - interval '3 days'
where token_hash = repeat('c', 64);

select is(
  (public.reconcile_google_play_subscription(
    repeat('c', 64), 'chronospark_premium_monthly', 'active', true, true,
    'order-test', now() + interval '30 days', now(),
    'verify:test:subscription',
    '{"source":"client_verification"}'::jsonb
  )->>'applied')::boolean,
  true,
  'verified subscription initializes the authoritative premium allowance'
);
select is(
  (select balance from public.monetization_wallets
   where user_id = '33333333-3333-4333-8333-333333333333'),
  300,
  'subscription reset matches the advertised monthly wallet balance'
);
select is(
  (select provider_event_time
   from public.monetization_subscription_statuses
   where user_id = '33333333-3333-4333-8333-333333333333'),
  now(),
  'subscription authority stores the Google provider event time'
);
select is(
  public.reconcile_google_play_subscription(
    repeat('c', 64), 'chronospark_premium_monthly', 'revoked', false, false,
    'order-test', now() + interval '30 days', now() - interval '1 hour',
    'rtdn:test:stale-current', '{"source":"test"}'::jsonb
  )->>'reason',
  'stale_event',
  'stale RTDN reconciliation is handled without changing authority'
);
select results_eq(
  $$select status, is_active, purchase_token_hash
    from public.monetization_subscription_statuses
    where user_id = '33333333-3333-4333-8333-333333333333'$$,
  $$values ('active'::text, true, repeat('c', 64))$$,
  'stale inactive RTDN leaves the current subscription active'
);
select is(
  (select balance from public.monetization_wallets
   where user_id = '33333333-3333-4333-8333-333333333333'),
  300,
  'stale inactive RTDN does not reset the premium wallet'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('c', 64), 'chronospark_premium_monthly', 'revoked', false, false,
    'order-test', now() + interval '30 days', now() - interval '1 hour',
    'rtdn:test:stale-current', '{"source":"test"}'::jsonb
  )->>'duplicate')::boolean,
  true,
  'stale RTDN reconciliation is idempotent'
);
select is(
  (public.reconcile_google_play_voided_purchase(
    repeat('c', 64), now() + interval '1 minute',
    'voided:test:subscription', 'order-test',
    '{"source":"test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'active subscription refund revokes immediately'
);
select results_eq(
  $$select status, is_active
    from public.monetization_subscription_statuses
    where user_id = '33333333-3333-4333-8333-333333333333'$$,
  $$values ('revoked'::text, false)$$,
  'active refund immediately deactivates subscription authority'
);
select is(
  (select balance from public.monetization_wallets
   where user_id = '33333333-3333-4333-8333-333333333333'),
  20,
  'active refund immediately resets the wallet to free allowance'
);
select is(
  (public.reconcile_google_play_voided_purchase(
    repeat('c', 64), now() + interval '1 minute',
    'voided:test:subscription', 'order-test',
    '{"source":"test"}'::jsonb
  )->>'duplicate')::boolean,
  true,
  'active refund replay is idempotent'
);
select is(
  public.reconcile_google_play_subscription(
    repeat('c', 64), 'chronospark_premium_monthly', 'active', true, true,
    'order-test', now() + interval '30 days', now() + interval '10 minutes',
    'verify:test:subscription-after-refund', '{"source":"test"}'::jsonb
  )->>'reason',
  'terminal_token',
  'successful verify replay becomes terminal after same-token refund'
);
select results_eq(
  $$select status, is_active
    from public.monetization_subscription_statuses
    where user_id = '33333333-3333-4333-8333-333333333333'$$,
  $$values ('revoked'::text, false)$$,
  'receipt verification leaves revoked authority inactive'
);

select is(
  (public.bind_verified_purchase_token(
    repeat('d', 64), '33333333-3333-4333-8333-333333333333',
    'chronospark_premium_monthly', now(), repeat('c', 64)
  )->>'bound')::boolean,
  true,
  'replacement predecessor token binds to the same account'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('d', 64), 'chronospark_premium_monthly', 'active', true, true,
    'order-old', now() + interval '30 days', now() + interval '2 minutes',
    'rtdn:test:old-active',
    '{"source":"google_play_rtdn","notificationType":2}'::jsonb
  )->>'applied')::boolean,
  true,
  'predecessor token becomes active before replacement'
);
select is(
  (public.bind_verified_purchase_token(
    repeat('e', 64), '33333333-3333-4333-8333-333333333333',
    'chronospark_premium_monthly', now() - interval '1 day', repeat('d', 64)
  )->>'bound')::boolean,
  true,
  'newer replacement token binds to the same account'
);
select results_eq(
  $$select predecessor_token_hash, created_at = now() - interval '1 day'
    from public.purchase_bindings where token_hash = repeat('e', 64)$$,
  $$values (repeat('d', 64), true)$$,
  'timestamped binding persists the linked predecessor and observation time'
);
select is(
  (select predecessor.created_at > successor.created_at
   from public.purchase_bindings predecessor
   join public.purchase_bindings successor
     on successor.token_hash = repeat('e', 64)
   where predecessor.token_hash = repeat('d', 64)),
  true,
  'linked predecessor may be bound later than its successor'
);
select is(
  public.bind_verified_purchase_token(
    repeat('e', 64), '33333333-3333-4333-8333-333333333333',
    'chronospark_premium_monthly', now(), repeat('c', 64)
  )->>'reason',
  'lineage_mismatch',
  'timestamped binding RPC cannot replace established lineage'
);
select throws_ok(
  $$update public.purchase_bindings
    set predecessor_token_hash = repeat('c', 64)
    where token_hash = repeat('e', 64)$$,
  'P0001',
  'purchase binding lineage is immutable',
  'direct service mutation cannot replace established lineage'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('e', 64), 'chronospark_premium_monthly', 'active', true, true,
    'order-new', now() + interval '31 days', now() + interval '3 minutes',
    'rtdn:test:new-active',
    '{"source":"google_play_rtdn","notificationType":2}'::jsonb
  )->>'applied')::boolean,
  true,
  'newer replacement token becomes authoritative'
);
select is(
  public.reconcile_google_play_subscription(
    repeat('d', 64), 'chronospark_premium_monthly', 'active', true, true,
    'order-old', now() + interval '32 days', now() + interval '4 minutes',
    'rtdn:test:old-active-replay', '{"source":"test"}'::jsonb
  )->>'reason',
  'old_token',
  'active predecessor token cannot replace a newer binding'
);
select is(
  public.reconcile_google_play_subscription(
    repeat('d', 64), 'chronospark_premium_monthly', 'expired', false, false,
    'order-old', now() + interval '30 days', now() + interval '4 minutes',
    'rtdn:test:old-expired', '{"source":"test"}'::jsonb
  )->>'reason',
  'old_token',
  'inactive predecessor token is handled without replacing current authority'
);
select is(
  (select purchase_state from public.monetization_purchases
   where purchase_token_hash = repeat('d', 64)),
  'expired',
  'inactive predecessor event updates predecessor purchase history'
);
select results_eq(
  $$select status, is_active, purchase_token_hash
    from public.monetization_subscription_statuses
    where user_id = '33333333-3333-4333-8333-333333333333'$$,
  $$values ('active'::text, true, repeat('e', 64))$$,
  'inactive predecessor event preserves the newer active token'
);
select is(
  (select balance from public.monetization_wallets
   where user_id = '33333333-3333-4333-8333-333333333333'),
  300,
  'inactive predecessor event preserves the premium wallet'
);
select is(
  public.reconcile_google_play_voided_purchase(
    repeat('d', 64), now() + interval '5 minutes',
    'rtdn:test:old-voided', 'order-old', '{"source":"test"}'::jsonb
  )->>'reason',
  'old_token',
  'voided predecessor token is handled without revoking current authority'
);
select is(
  (select purchase_state from public.monetization_purchases
   where purchase_token_hash = repeat('d', 64)),
  'refunded',
  'voided predecessor token updates predecessor purchase history'
);
select results_eq(
  $$select s.status, s.is_active, s.purchase_token_hash, w.balance
    from public.monetization_subscription_statuses s
    join public.monetization_wallets w using (user_id)
    where s.user_id = '33333333-3333-4333-8333-333333333333'$$,
  $$values ('active'::text, true, repeat('e', 64), 300)$$,
  'voided predecessor token preserves newer authority and wallet'
);
select is(
  (public.reconcile_google_play_voided_purchase(
    repeat('d', 64), now() + interval '5 minutes',
    'rtdn:test:old-voided', 'order-old', '{"source":"test"}'::jsonb
  )->>'duplicate')::boolean,
  true,
  'voided predecessor replay is idempotent'
);
select is(
  (select count(*)::integer
   from public.monetization_entitlement_events
   where event_key = 'rtdn:test:old-voided'),
  1,
  'voided predecessor replay records one entitlement event'
);

select is(
  (public.reconcile_google_play_subscription(
    repeat('e', 64), 'chronospark_premium_monthly', 'expired', false, false,
    'order-new', now() + interval '31 days', now() + interval '6 minutes',
    'rtdn:test:equal-inactive', '{"source":"test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'equal-time inactive event wins when active authority arrived first'
);
select results_eq(
  $$select status, is_active from public.monetization_subscription_statuses
    where user_id = '33333333-3333-4333-8333-333333333333'$$,
  $$values ('expired'::text, false)$$,
  'equal-time inactive event makes authority inactive'
);
select is(
  public.reconcile_google_play_subscription(
    repeat('e', 64), 'chronospark_premium_monthly', 'active', true, true,
    'order-new', now() + interval '31 days', now() + interval '6 minutes',
    'rtdn:test:equal-active-no-renewal', '{"source":"test"}'::jsonb
  )->>'reason',
  'stale_event',
  'equal-time active replay cannot reverse inactive authority'
);
select results_eq(
  $$select status, is_active from public.monetization_subscription_statuses
    where user_id = '33333333-3333-4333-8333-333333333333'$$,
  $$values ('expired'::text, false)$$,
  'inactive authority remains deterministic when active arrives second'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('e', 64), 'chronospark_premium_monthly', 'active', true, true,
    'order-new-renewed', now() + interval '32 days',
    now() + interval '6 minutes', 'rtdn:test:equal-active-renewal',
    '{"source":"google_play_rtdn","notificationType":2}'::jsonb
  )->>'applied')::boolean,
  true,
  'provider paid-renewal signal can restore equal-time inactive authority'
);
select results_eq(
  $$select s.status, s.is_active, w.balance,
      s.expires_at = now() + interval '32 days'
    from public.monetization_subscription_statuses s
    join public.monetization_wallets w using (user_id)
    where s.user_id = '33333333-3333-4333-8333-333333333333'$$,
  $$values ('active'::text, true, 300, true)$$,
  'proven equal-time renewal restores active premium authority'
);

select is(
  (public.claim_google_play_rtdn_event(
    'claim-test-message', 'com.ghostheart5.chronospark', now(),
    'subscription', '{"source":"test"}'::jsonb
  )->>'claimed')::boolean,
  true,
  'first RTDN delivery atomically claims the message'
);
select is(
  (public.claim_google_play_rtdn_event(
    'claim-test-message', 'com.ghostheart5.chronospark', now(),
    'subscription', '{"source":"test"}'::jsonb
  )->>'claimed')::boolean,
  false,
  'concurrent RTDN delivery cannot claim an active lease'
);
update public.google_play_rtdn_events
set state = 'processed', processed_at = now()
where message_id = 'claim-test-message';
select is(
  (public.claim_google_play_rtdn_event(
    'claim-test-message', 'com.ghostheart5.chronospark', now(),
    'subscription', '{"source":"test"}'::jsonb
  )->>'completed')::boolean,
  true,
  'processed RTDN delivery is acknowledged without reconciliation replay'
);

update public.monetization_subscription_statuses
set expires_at = now() - interval '25 hours',
  provider_event_time = now() - interval '26 hours'
where user_id = '33333333-3333-4333-8333-333333333333';
select is(
  public.expire_stale_monetization_subscriptions(),
  1,
  'scheduled expiry function queues stale premium authority for provider recheck'
);
select is(
  (select provider_event_time
   from public.monetization_subscription_statuses
   where user_id = '33333333-3333-4333-8333-333333333333'),
  now() - interval '26 hours',
  'local expiry does not advance the Google provider watermark'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('e', 64), 'chronospark_premium_monthly', 'active', true, true,
    'order-new-renewed', now() + interval '32 days',
    now() - interval '1 minute', 'verify:test:late-renewal',
    '{"source":"client_verification"}'::jsonb
  )->>'applied')::boolean,
  true,
  'Play-verified delayed renewal restores locally expired premium'
);
select results_eq(
  $$select s.status, s.is_active, s.purchase_token_hash, w.balance
    from public.monetization_subscription_statuses s
    join public.monetization_wallets w using (user_id)
    where s.user_id = '33333333-3333-4333-8333-333333333333'$$,
  $$values ('active'::text, true, repeat('e', 64), 300)$$,
  'delayed renewal restores newer-token authority and premium wallet'
);
select is(
  (select sum(amount)::integer from public.monetization_credit_transactions
   where user_id = '33333333-3333-4333-8333-333333333333'),
  (select balance from public.monetization_wallets
   where user_id = '33333333-3333-4333-8333-333333333333'),
  'initialization, resets, spends, and refunds conserve the ledger balance'
);

reset role;

select ok(
  has_column_privilege(
    'service_role', 'public.purchase_bindings', 'created_at', 'UPDATE'
  ),
  'service role retains created-at row-lock privilege'
);
select ok(
  not has_column_privilege(
    'service_role', 'public.purchase_bindings', 'token_hash', 'UPDATE'
  ),
  'service role cannot update the purchase token hash'
);
select ok(
  not has_column_privilege(
    'service_role', 'public.purchase_bindings', 'user_id', 'UPDATE'
  ),
  'service role cannot reassign a purchase binding to another account'
);
select ok(
  not has_column_privilege(
    'service_role', 'public.purchase_bindings', 'product_id', 'UPDATE'
  ),
  'service role cannot change the bound product'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.refund_stale_ai_usage_reservations(interval)',
    'EXECUTE'
  ),
  'service role can execute scheduled stale-reservation refunds'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.expire_stale_monetization_subscriptions()',
    'EXECUTE'
  ),
  'service role can execute scheduled subscription expiry'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.refund_stale_ai_usage_reservations(interval)',
    'EXECUTE'
  ),
  'authenticated clients cannot execute stale-reservation refunds'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.expire_stale_monetization_subscriptions()',
    'EXECUTE'
  ),
  'authenticated clients cannot execute subscription expiry'
);
select results_eq(
  $$select count(*) from cron.job
    where jobname = 'chronospark-refund-stale-ai-reservations'$$,
  array[1::bigint],
  'exactly one stale-reservation refund job is scheduled'
);
select results_eq(
  $$select command from cron.job
    where jobname = 'chronospark-refund-stale-ai-reservations'$$,
  array['select public.refund_stale_ai_usage_reservations(interval ''10 minutes'');'::text],
  'stale-reservation job calls the schema-qualified refund function'
);
select results_eq(
  $$select has_function_privilege(
      username::name,
      'public.refund_stale_ai_usage_reservations(interval)',
      'EXECUTE'
    )
    from cron.job
    where jobname = 'chronospark-refund-stale-ai-reservations'$$,
  array[true],
  'scheduled refund job owner can execute its maintenance function'
);
select results_eq(
  $$select count(*) from cron.job
    where jobname = 'chronospark-expire-stale-subscriptions'$$,
  array[1::bigint],
  'exactly one stale-subscription expiry job is scheduled'
);
select results_eq(
  $$select command from cron.job
    where jobname = 'chronospark-expire-stale-subscriptions'$$,
  array['select public.expire_stale_monetization_subscriptions();'::text],
  'stale-subscription job calls the schema-qualified expiry function'
);
select results_eq(
  $$select has_function_privilege(
      username::name,
      'public.expire_stale_monetization_subscriptions()',
      'EXECUTE'
    )
    from cron.job
    where jobname = 'chronospark-expire-stale-subscriptions'$$,
  array[true],
  'scheduled expiry job owner can execute its maintenance function'
);

set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';

select results_eq(
  'select balance from public.monetization_wallets',
  array[300],
  'authenticated account reads only its wallet'
);
select throws_ok(
  $$update public.monetization_wallets set balance = 999$$,
  '42501',
  'permission denied for table monetization_wallets',
  'client cannot mutate the server wallet'
);
select throws_ok(
  $$insert into public.monetization_credit_transactions
      (user_id, type, amount, balance_after, source, description)
    values
      ('33333333-3333-4333-8333-333333333333', 'mint', 100, 120, 'client', 'forbidden')$$,
  '42501',
  'permission denied for table monetization_credit_transactions',
  'client cannot forge ledger entries'
);

set local request.jwt.claim.sub = '44444444-4444-4444-8444-444444444444';
select results_eq(
  'select count(*) from public.monetization_wallets',
  array[0::bigint],
  'second account cannot read the first account wallet'
);

reset role;
delete from auth.users where id = '33333333-3333-4333-8333-333333333333';
select results_eq(
  $$select count(*) from public.monetization_credit_transactions
    where user_id = '33333333-3333-4333-8333-333333333333'$$,
  array[0::bigint],
  'account deletion cascades billing records'
);

select * from finish();
rollback;
