begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

select has_table(
  'public',
  'account_deletion_requests',
  'durable account deletion requests exist'
);

select results_eq(
  $$
    select relrowsecurity
    from pg_class
    where oid = 'public.account_deletion_requests'::regclass
  $$,
  array[true],
  'account deletion requests have RLS enabled'
);

select ok(
  not has_table_privilege('anon', 'public.account_deletion_requests', 'SELECT'),
  'anonymous users cannot read deletion requests'
);

select ok(
  not has_table_privilege('authenticated', 'public.account_deletion_requests', 'SELECT'),
  'authenticated users cannot read deletion requests directly'
);

select ok(
  has_table_privilege('service_role', 'public.account_deletion_requests', 'SELECT'),
  'the server role can resume deletion requests'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.claim_account_deletion_request(text,text,uuid,uuid,boolean)',
    'EXECUTE'
  ),
  'only the server workflow receives the claim capability'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.claim_account_deletion_request(text,text,uuid,uuid,boolean)',
    'EXECUTE'
  ),
  'authenticated clients cannot claim deletion leases directly'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.account_deletion_in_progress()',
    'EXECUTE'
  ),
  'storage policies can query the authenticated deletion tombstone'
);

select results_eq(
  $$
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in ('chronospark_sync_insert_own', 'chronospark_sync_update_own')
      and coalesce(with_check, '') like '%account_deletion_in_progress%'
  $$,
  array[2::bigint],
  'sync insert and update policies block deletion tombstones'
);

insert into public.account_deletion_requests (
  request_id,
  user_id,
  receipt_hash,
  state
) values (
  repeat('a', 64),
  '11111111-1111-4111-8111-111111111111',
  repeat('b', 64),
  'completed'
);

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select is(
  public.account_deletion_in_progress(),
  true,
  'a completed request remains a storage-write tombstone for a lingering JWT'
);

select * from finish();
rollback;
