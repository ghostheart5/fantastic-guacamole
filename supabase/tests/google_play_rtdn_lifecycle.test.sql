begin;

create extension if not exists pgtap with schema extensions;
select plan(44);

insert into auth.users (id, email) values
  ('44000000-0000-4000-8000-000000000001', 'repair4-lifecycle-a@example.invalid'),
  ('44000000-0000-4000-8000-000000000002', 'repair4-lifecycle-b@example.invalid'),
  ('44000000-0000-4000-8000-000000000003', 'repair4-lifecycle-c@example.invalid'),
  ('44000000-0000-4000-8000-000000000004', 'repair4-lifecycle-d@example.invalid'),
  ('44000000-0000-4000-8000-000000000005', 'repair4-lifecycle-e@example.invalid');

set local role service_role;

select is(
  (public.bind_verified_purchase_token(
    repeat('1', 64), '44000000-0000-4000-8000-000000000001',
    'chronospark_premium_monthly'
  )->>'bound')::boolean,
  true,
  'grace and cancellation fixture binds its current purchase token'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('1', 64), 'chronospark_premium_monthly', 'active', true, true,
    'repair4-order-a', now() + interval '30 days',
    now() - interval '10 minutes', 'repair4:a:active',
    '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'active subscription initializes premium authority for lifecycle testing'
);
select is(
  (public.reserve_ai_usage(
    '44000000-0000-4000-8000-000000000001',
    'repair4-spend-a', 3, repeat('a', 64)
  )->>'allowed')::boolean,
  true,
  'premium fixture spends credits before a non-renewal transition'
);
select is(
  public.settle_ai_usage(
    '44000000-0000-4000-8000-000000000001',
    'repair4-spend-a', true, 10, 20, 'repair4-provider-a', null,
    '{}'::jsonb
  )->>'state',
  'completed',
  'spent credits are settled and cannot be refunded as an abandoned request'
);
select results_eq(
  $$select balance, allowance_remaining, lifetime_spent, tier
    from public.monetization_wallets
    where user_id = '44000000-0000-4000-8000-000000000001'$$,
  $$values (297, 297, 3, 'premium_monthly'::text)$$,
  'fixture records the already-spent premium allowance'
);
update public.monetization_wallets
set period_ends_at = now() - interval '1 minute'
where user_id = '44000000-0000-4000-8000-000000000001';
select is(
  (public.reconcile_google_play_subscription(
    repeat('1', 64), 'chronospark_premium_monthly', 'grace', true, true,
    'repair4-order-a', now() + interval '31 days',
    now() - interval '5 minutes', 'repair4:a:grace',
    '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'grace state is accepted as active authority'
);
select is(
  (select (metadata->>'providerEventTime') is not null
   from public.monetization_subscription_statuses
   where user_id = '44000000-0000-4000-8000-000000000001'),
  true,
  'grace transition records the provider event watermark'
);
select results_eq(
  $$select status, is_active, auto_renews
    from public.monetization_subscription_statuses
    where user_id = '44000000-0000-4000-8000-000000000001'$$,
  $$values ('grace'::text, true, true)$$,
  'grace retains premium entitlement while Play retries payment'
);
select results_eq(
  $$select balance, allowance_remaining, lifetime_spent, tier
    from public.monetization_wallets
    where user_id = '44000000-0000-4000-8000-000000000001'$$,
  $$values (297, 297, 3, 'premium_monthly'::text)$$,
  'grace does not replenish credits already spent this period'
);
select is(
  (public.reserve_ai_usage(
    '44000000-0000-4000-8000-000000000001',
    'repair4-spend-in-grace', 1, repeat('b', 64)
  )->>'balance')::integer,
  296,
  'first use after an extended grace transition does not reset allowance'
);
select results_eq(
  $$select balance, allowance_remaining, lifetime_spent,
      period_ends_at = now() + interval '31 days'
    from public.monetization_wallets
    where user_id = '44000000-0000-4000-8000-000000000001'$$,
  $$values (296, 296, 4, true)$$,
  'extended grace advances the wallet boundary without replenishing credits'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('1', 64), 'chronospark_premium_monthly', 'canceled', true, false,
    'repair4-order-a', now() + interval '31 days', now(),
    'repair4:a:canceled-before-expiry',
    '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'pre-expiry cancellation is accepted as active non-renewing authority'
);
select results_eq(
  $$select status, is_active, auto_renews
    from public.monetization_subscription_statuses
    where user_id = '44000000-0000-4000-8000-000000000001'$$,
  $$values ('canceled'::text, true, false)$$,
  'cancellation preserves entitlement through the paid expiry time'
);
select results_eq(
  $$select balance, allowance_remaining, lifetime_spent, tier
    from public.monetization_wallets
    where user_id = '44000000-0000-4000-8000-000000000001'$$,
  $$values (296, 296, 4, 'premium_monthly'::text)$$,
  'cancellation does not replenish credits already spent this period'
);
update public.monetization_subscription_statuses
set expires_at = now() - interval '1 minute'
where user_id = '44000000-0000-4000-8000-000000000001';
select is(
  public.expire_stale_monetization_subscriptions(),
  1,
  'canceled authority expires at its paid-through time without extra delay'
);
select results_eq(
  $$select s.status, s.is_active, w.tier
    from public.monetization_subscription_statuses s
    join public.monetization_wallets w using (user_id)
    where s.user_id = '44000000-0000-4000-8000-000000000001'$$,
  $$values ('expired'::text, false, 'free'::text)$$,
  'canceled fallback expiry removes premium authority immediately'
);

select is(
  (public.bind_verified_purchase_token(
    repeat('2', 64), '44000000-0000-4000-8000-000000000002',
    'chronospark_premium_monthly'
  )->>'bound')::boolean,
  true,
  'delayed revocation fixture binds its current purchase token'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('2', 64), 'chronospark_premium_monthly', 'active', true, true,
    'repair4-order-b', now() + interval '30 days', now(),
    'repair4:b:active', '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'delayed revocation fixture starts with active current-token authority'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('2', 64), 'chronospark_premium_monthly', 'revoked', false, false,
    'repair4-order-b', now() + interval '30 days',
    now() + interval '1 minute', 'repair4:b:delayed-revoked',
    jsonb_build_object(
      'source', 'repair4-test',
      'notificationEventTime', now() - interval '1 hour',
      'notificationType', 12,
      'subscriptionState', 'SUBSCRIPTION_STATE_EXPIRED'
    )
  )->>'applied')::boolean,
  true,
  'delayed current-token revocation remains terminal authority'
);
select results_eq(
  $$select s.status, s.is_active, s.auto_renews, w.tier
    from public.monetization_subscription_statuses s
    join public.monetization_wallets w using (user_id)
    where s.user_id = '44000000-0000-4000-8000-000000000002'$$,
  $$values ('revoked'::text, false, false, 'free'::text)$$,
  'revocation immediately removes entitlement even when delivery is delayed'
);

select is(
  (public.bind_verified_purchase_token(
    repeat('3', 64), '44000000-0000-4000-8000-000000000003',
    'chronospark_premium_monthly'
  )->>'bound')::boolean,
  true,
  'delayed refund fixture binds its current purchase token'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('3', 64), 'chronospark_premium_monthly', 'active', true, true,
    'repair4-order-c', now() + interval '30 days', now(),
    'repair4:c:active', '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'delayed refund fixture starts with active current-token authority'
);
select is(
  (public.reconcile_google_play_voided_purchase(
    repeat('3', 64), now() - interval '1 hour',
    'repair4:c:delayed-refund', 'repair4-order-c',
    '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'delayed refund of the current token remains terminal authority'
);
select results_eq(
  $$select s.status, s.is_active, s.auto_renews, w.tier
    from public.monetization_subscription_statuses s
    join public.monetization_wallets w using (user_id)
    where s.user_id = '44000000-0000-4000-8000-000000000003'$$,
  $$values ('revoked'::text, false, false, 'free'::text)$$,
  'current-token refund immediately removes subscription entitlement'
);
select is(
  (select purchase_state from public.monetization_purchases
   where purchase_token_hash = repeat('3', 64)),
  'refunded',
  'current-token refund remains authoritative in purchase history'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('3', 64), 'chronospark_premium_monthly', 'expired', false, false,
    'repair4-order-c', now() - interval '1 hour', now() + interval '1 minute',
    'repair4:c:expired-after-refund', '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'expiry after refund remains an inactive terminal transition'
);
select is(
  (select purchase_state from public.monetization_purchases
   where purchase_token_hash = repeat('3', 64)),
  'refunded',
  'expiry cannot erase the permanent refund marker'
);
select is(
  public.reconcile_google_play_subscription(
    repeat('3', 64), 'chronospark_premium_monthly', 'active', true, true,
    'repair4-order-c', now() + interval '30 days', now() + interval '2 minutes',
    'repair4:c:active-after-refund', '{"source":"repair4-test"}'::jsonb
  )->>'reason',
  'terminal_token',
  'a refunded token cannot regain active authority after expiry'
);

select is(
  (public.bind_verified_purchase_token(
    repeat('4', 64), '44000000-0000-4000-8000-000000000004',
    'chronospark_premium_monthly'
  )->>'bound')::boolean,
  true,
  'expiry fixture binds its current purchase token'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('4', 64), 'chronospark_premium_monthly', 'active', true, true,
    'repair4-order-d', now() + interval '30 days', now(),
    'repair4:d:active', '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'expiry fixture starts with active entitlement'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('4', 64), 'chronospark_premium_monthly', 'expired', false, false,
    'repair4-order-d', now() + interval '30 days',
    now() + interval '1 minute', 'repair4:d:expired',
    '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'explicit expiry removes entitlement without waiting for stored expiry time'
);
select results_eq(
  $$select s.status, s.is_active, s.auto_renews, w.tier
    from public.monetization_subscription_statuses s
    join public.monetization_wallets w using (user_id)
    where s.user_id = '44000000-0000-4000-8000-000000000004'$$,
  $$values ('expired'::text, false, false, 'free'::text)$$,
  'explicit expiry immediately removes premium authority'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('4', 64), 'chronospark_premium_monthly', 'grace', true, true,
    'repair4-order-d', now() - interval '1 minute',
    now() + interval '2 minutes', 'repair4:d:stale-grace',
    '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'explicit grace fixture can model a missed terminal event'
);
select is(
  public.expire_stale_monetization_subscriptions(),
  1,
  'explicit grace with a past Play expiry receives no silent-grace delay'
);
select results_eq(
  $$select status, is_active from public.monetization_subscription_statuses
    where user_id = '44000000-0000-4000-8000-000000000004'$$,
  $$values ('expired'::text, false)$$,
  'past-expiry grace fallback removes entitlement immediately'
);

select is(
  (public.bind_verified_purchase_token(
    repeat('5', 64), '44000000-0000-4000-8000-000000000005',
    'chronospark_premium_monthly'
  )->>'bound')::boolean,
  true,
  'silent-grace fixture binds its current purchase token'
);
select is(
  (public.reconcile_google_play_subscription(
    repeat('5', 64), 'chronospark_premium_monthly', 'active', true, true,
    'repair4-order-e', now() + interval '30 days', now(),
    'repair4:e:active', '{"source":"repair4-test"}'::jsonb
  )->>'applied')::boolean,
  true,
  'silent-grace fixture starts with active entitlement'
);
select is(
  (public.reserve_ai_usage(
    '44000000-0000-4000-8000-000000000005',
    'repair4-spend-e', 3, repeat('e', 64)
  )->>'balance')::integer,
  297,
  'silent-grace fixture spends credits before the renewal boundary'
);
select is(
  public.settle_ai_usage(
    '44000000-0000-4000-8000-000000000005',
    'repair4-spend-e', true, 10, 20, 'repair4-provider-e', null,
    '{}'::jsonb
  )->>'state',
  'completed',
  'silent-grace fixture settles its pre-boundary spend'
);
update public.monetization_subscription_statuses
set expires_at = now() - interval '23 hours 59 minutes'
where user_id = '44000000-0000-4000-8000-000000000005';
update public.monetization_wallets
set period_ends_at = now() - interval '23 hours 59 minutes'
where user_id = '44000000-0000-4000-8000-000000000005';
select is(
  public.expire_stale_monetization_subscriptions(),
  0,
  'scheduled expiry preserves Play active state inside silent grace'
);
select is(
  (public.reserve_ai_usage(
    '44000000-0000-4000-8000-000000000005',
    'repair4-spend-in-silent-grace', 1, repeat('f', 64)
  )->>'balance')::integer,
  296,
  'first use in silent grace preserves premium credits without a refill'
);
select results_eq(
  $$select s.status, s.is_active, w.tier, w.balance,
      w.allowance_remaining, w.period_ends_at > now()
    from public.monetization_subscription_statuses s
    join public.monetization_wallets w using (user_id)
    where s.user_id = '44000000-0000-4000-8000-000000000005'$$,
  $$values ('active'::text, true, 'premium_monthly'::text, 296, 296, true)$$,
  'silent-grace subscription retains entitlement before the 24-hour boundary'
);
update public.monetization_subscription_statuses
set status = 'active', is_active = true, auto_renews = true,
  expires_at = now() - interval '24 hours 1 minute'
where user_id = '44000000-0000-4000-8000-000000000005';
select is(
  public.expire_stale_monetization_subscriptions(),
  1,
  'scheduled expiry removes silent-grace entitlement after 24 hours'
);
select results_eq(
  $$select s.status, s.is_active, s.auto_renews, w.tier
    from public.monetization_subscription_statuses s
    join public.monetization_wallets w using (user_id)
    where s.user_id = '44000000-0000-4000-8000-000000000005'$$,
  $$values ('expired'::text, false, false, 'free'::text)$$,
  'post-boundary scheduled expiry removes premium authority'
);

reset role;

select * from finish();
rollback;
