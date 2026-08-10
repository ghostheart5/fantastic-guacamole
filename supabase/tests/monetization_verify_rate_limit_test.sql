begin;
select plan(2);

insert into auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000302', 'authenticated', 'authenticated', 'verify-rate-limit@example.test', '{}'::jsonb, '{}'::jsonb, now(), now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000302', true);

select lives_ok(
  $$select public.consume_monetization_verify_rate_limit() from generate_series(1, 10)$$,
  'the configured request window accepts its first ten verification requests'
);
select throws_ok(
  $$select public.consume_monetization_verify_rate_limit()$$,
  'rate limit exceeded',
  'the next verification request is rejected by the shared rate limiter'
);

select * from finish();
rollback;
