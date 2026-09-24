begin;

create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'device-a@example.invalid'),
  ('22222222-2222-4222-8222-222222222222', 'device-b@example.invalid');

select ok(
  not has_table_privilege('authenticated', 'public.firebase_device_registrations', 'SELECT'),
  'authenticated callers cannot read raw messaging tokens'
);
select ok(
  not has_table_privilege('authenticated', 'public.firebase_device_registrations', 'INSERT'),
  'authenticated callers cannot bypass the registration RPC'
);
select ok(
  not has_function_privilege('anon', 'public.register_firebase_device(text,text,text,text)', 'EXECUTE'),
  'anonymous callers cannot register devices'
);

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select is(
  (select count(*) from (
    select public.register_firebase_device(
      'installation-aaaaaaaa-' || n,
      'token-aaaaaaaa-' || n,
      'android',
      'startup'
    ) as registration_id
    from generate_series(1, 20) n
  ) registrations where registration_id > 0),
  20::bigint,
  'the first twenty distinct installations are accepted'
);
select is(
  public.register_firebase_device(
    'installation-aaaaaaaa-21', 'token-aaaaaaaa-21', 'android', 'startup'
  ),
  0::bigint,
  'a twenty-first distinct installation is rejected without an exception'
);
select ok(
  public.register_firebase_device(
    'installation-aaaaaaaa-1', 'token-rotated-aaaa-1', 'android', 'token_refresh'
  ) > 0,
  'an existing installation can rotate its token at the limit'
);
select ok(
  public.register_firebase_device(
    'installation-aaaaaaaa-new', 'token-aaaaaaaa-3', 'android', 'restore'
  ) > 0,
  'the same account can rebind its existing token at the limit'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select is(
  public.register_firebase_device(
    'installation-bbbbbbbb-1', 'token-aaaaaaaa-2', 'android', 'startup'
  ),
  0::bigint,
  'a token alone cannot take another account registration'
);
select ok(
  public.register_firebase_device(
    'installation-aaaaaaaa-1', 'token-bbbbbbbb-1', 'android', 'account_switch'
  ) > 0,
  'the same installation ID can change account ownership'
);

reset role;
select is(
  (select count(*) from public.firebase_device_registrations
   where user_id = '11111111-1111-4111-8111-111111111111'),
  19::bigint,
  'the first account retains only its other nineteen devices'
);
select is(
  (select count(*) from public.firebase_device_registrations
   where user_id = '22222222-2222-4222-8222-222222222222'),
  1::bigint,
  'the second account owns the transferred installation'
);

set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select is(
  (select count(*) from (
    select public.register_firebase_device(
      'installation-bbbbbbbb-' || n,
      'token-bbbbbbbb-' || n,
      'android',
      'startup'
    ) as registration_id
    from generate_series(2, 20) n
  ) registrations where registration_id > 0),
  19::bigint,
  'the second account reaches its twenty-device cap'
);

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
select ok(
  public.register_firebase_device(
    'installation-aaaaaaaa-shared', 'token-aaaaaaaa-shared', 'android', 'startup'
  ) > 0,
  'the previous owner has a shared installation'
);

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
select is(
  public.register_firebase_device(
    'installation-aaaaaaaa-shared', 'token-bbbbbbbb-shared', 'android', 'account_switch'
  ),
  0::bigint,
  'a cap rejection does not claim the new account installation'
);

reset role;
select is(
  (select count(*) from public.firebase_device_registrations
   where installation_id = 'installation-aaaaaaaa-shared'),
  0::bigint,
  'a cap rejection removes the previous owner''s stale installation'
);

select * from finish();
rollback;
