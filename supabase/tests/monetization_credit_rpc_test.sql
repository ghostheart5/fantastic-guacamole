begin;
select plan(8);

insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000201', 'authenticated', 'authenticated', 'credit-rpc@example.test', '{}'::jsonb, '{}'::jsonb, now(), now());
insert into public.monetization_wallets (
  user_id, balance, allowance_remaining, bonus_balance, period_credits,
  lifetime_earned, lifetime_spent, tier, period_ends_at
)
values ('00000000-0000-0000-0000-000000000201', 10, 10, 0, 10, 10, 0, 'free', now() + interval '1 day');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000201', true);

select throws_ok(
  $$select * from public.consume_monetization_credits(-1, 'test', '{}'::jsonb)$$,
  'credit amount must be between 1 and 1000',
  'negative credit consumption is rejected'
);

select throws_ok(
  $$select * from public.consume_monetization_credits(0, 'test', '{}'::jsonb)$$,
  'credit amount must be between 1 and 1000',
  'zero credit consumption is rejected'
);

select lives_ok(
  $$select * from public.consume_monetization_credits(3, 'test', '{}'::jsonb)$$,
  'positive credit consumption succeeds'
);
select is(
  (select balance from public.monetization_wallets where user_id = auth.uid()),
  7,
  'positive consumption decrements the balance'
);
select throws_ok(
  $$select * from public.consume_monetization_credits(8, 'test', '{}'::jsonb)$$,
  'insufficient credits',
  'insufficient credit consumption fails'
);
select is(
  (select balance from public.monetization_wallets where user_id = auth.uid()),
  7,
  'consume RPC never increases the balance'
);

reset role;
update public.monetization_wallets
set balance = 7,
    allowance_remaining = 7,
    bonus_balance = 0,
    period_credits = 10,
    period_ends_at = now() - interval '1 minute'
where user_id = '00000000-0000-0000-0000-000000000201';
set local role authenticated;

select lives_ok(
  $$select * from public.consume_monetization_credits(1, 'expired allowance refresh', '{}'::jsonb)$$,
  'expired allowance refresh succeeds without ambiguous wallet columns'
);
select is(
  (select balance from public.monetization_wallets where user_id = auth.uid()),
  19,
  'expired free allowance resets before consuming one credit'
);

select * from finish();
rollback;
