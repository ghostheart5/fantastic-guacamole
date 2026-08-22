begin;
select plan(7);

select ok(
  has_function_privilege(
    'service_role',
    'public.apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb)',
    'EXECUTE'
  )
    and not has_function_privilege(
      'public',
      'public.apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb)',
      'EXECUTE'
    )
    and not has_function_privilege(
      'anon',
      'public.apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb)',
      'EXECUTE'
    )
    and not has_function_privilege(
      'authenticated',
      'public.apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb)',
      'EXECUTE'
    ),
  'verified purchase remains service-role only'
);

insert into auth.users (
  id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000202',
  'authenticated',
  'authenticated',
  'purchase-rpc@example.test',
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

set local role service_role;

select is(
  public.apply_verified_purchase(
    '00000000-0000-0000-0000-000000000202',
    'chronospark_credits_100',
    'consumable',
    'pgtap-purchase-token-202',
    'pgtap-order-202',
    '2026-08-22 18:00:00+00'::timestamptz,
    null,
    '{"source":"pgtap"}'::jsonb
  )->>'applied',
  'true',
  'first verified receipt is applied'
);

select is(
  public.apply_verified_purchase(
    '00000000-0000-0000-0000-000000000202',
    'chronospark_credits_100',
    'consumable',
    'pgtap-purchase-token-202',
    'pgtap-order-202',
    '2026-08-22 18:00:00+00'::timestamptz,
    null,
    '{"source":"pgtap"}'::jsonb
  )->>'duplicate',
  'true',
  'replayed receipt is reported as a duplicate'
);

select is(
  (
    select count(*)
    from public.monetization_purchases
    where user_id = '00000000-0000-0000-0000-000000000202'
      and purchase_token_hash = 'pgtap-purchase-token-202'
  ),
  1::bigint,
  'duplicate receipt creates one purchase row'
);

select is(
  (
    select bonus_balance
    from public.monetization_wallets
    where user_id = '00000000-0000-0000-0000-000000000202'
  ),
  100,
  'duplicate receipt grants the credit pack once'
);

select is(
  (
    select count(*)
    from public.monetization_credit_transactions
    where user_id = '00000000-0000-0000-0000-000000000202'
      and type = 'purchase_grant'
  ),
  1::bigint,
  'duplicate receipt records one credit transaction'
);

select is(
  (
    select count(*)
    from public.monetization_entitlement_events
    where user_id = '00000000-0000-0000-0000-000000000202'
      and product_id = 'chronospark_credits_100'
  ),
  1::bigint,
  'duplicate receipt records one entitlement event'
);

select * from finish();
rollback;
