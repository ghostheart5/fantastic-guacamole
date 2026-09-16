begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select ok(not has_function_privilege('anon',
  'public.consume_monetization_credits(integer,text,jsonb)', 'EXECUTE'),
  'anonymous clients cannot invoke the retired direct debit');
select ok(not has_function_privilege('authenticated',
  'public.consume_monetization_credits(integer,text,jsonb)', 'EXECUTE'),
  'authenticated clients cannot bypass quote/reserve/settle');
select ok(not has_function_privilege('service_role',
  'public.consume_monetization_credits(integer,text,jsonb)', 'EXECUTE'),
  'server credentials cannot accidentally use obsolete allowance rules');
select ok(not exists (
  select 1 from pg_proc p
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
  where p.oid = 'public.consume_monetization_credits(integer,text,jsonb)'::regprocedure
    and a.grantee = 0 and a.privilege_type = 'EXECUTE'
), 'PUBLIC inheritance cannot restore the retired debit');

select ok(has_function_privilege('service_role',
  'public.reserve_ai_usage(uuid,text,integer,text)', 'EXECUTE'),
  'canonical server reservation remains available');
select ok(not has_function_privilege('authenticated',
  'public.reserve_ai_usage(uuid,text,integer,text)', 'EXECUTE'),
  'clients cannot directly invoke the canonical server reservation');

select * from finish();
rollback;
