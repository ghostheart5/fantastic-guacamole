begin;

create extension if not exists pgtap with schema extensions;
select plan(37);

select has_table('public', 'monetization_wallets', 'wallet table exists');
select has_table('public', 'monetization_credit_transactions', 'credit ledger exists');
select has_table('public', 'ai_usage_requests', 'AI reservation table exists');
select has_table('public', 'backend_rate_limits', 'durable rate table exists');

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
  (public.reconcile_google_play_subscription(
    repeat('c', 64), 'chronospark_premium_monthly', 'active', true, true,
    'order-test', now() + interval '30 days', 'verify:test:subscription',
    '{"source":"test"}'::jsonb
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
update public.monetization_subscription_statuses
set expires_at = now() - interval '1 minute'
where user_id = '33333333-3333-4333-8333-333333333333';
select is(
  public.expire_stale_monetization_subscriptions(),
  1,
  'scheduled expiry function removes stale premium access'
);
select is(
  (select balance from public.monetization_wallets
   where user_id = '33333333-3333-4333-8333-333333333333'),
  20,
  'scheduled expiry resets the wallet to the free allowance'
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
  array[20],
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
