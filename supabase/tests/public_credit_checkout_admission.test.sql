begin;
create extension if not exists pgtap with schema extensions;
select plan(1);
insert into auth.users(id,email) values
 ('91919191-9191-4191-8191-919191919191','public-credit-a@example.invalid'),
 ('92929292-9292-4292-8292-929292929292','public-credit-b@example.invalid');
set local role service_role;
do $$
declare
  a constant uuid := '91919191-9191-4191-8191-919191919191';
  b constant uuid := '92929292-9292-4292-8292-929292929292';
  admission jsonb; admission_id text; result jsonb;
  purchased_at bigint := floor(extract(epoch from now()) * 1000)::bigint;
begin
  assert not has_function_privilege('anon',
    'public.create_public_credit_checkout_admission(uuid,text)', 'execute'),
    'anonymous cannot issue public checkout admissions';
  assert not has_function_privilege('authenticated',
    'public.grant_verified_credit_topup_v2(uuid,text,text,text,boolean,text,bigint)', 'execute'),
    'app clients cannot grant credits';
  admission := public.create_public_credit_checkout_admission(a,'chronospark_credits_100');
  assert (admission->>'allowed')::boolean, 'server could not create admission';
  admission_id := admission->>'admissionId';
  result := public.grant_verified_credit_topup_v2(
    b,repeat('a',64),'chronospark_credits_100','GPA.public-a',false,
    admission_id,purchased_at);
  assert result->>'reason'='admission_invalid', 'other account used admission';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('a',64),'chronospark_credits_300','GPA.public-a',false,
    admission_id,purchased_at);
  assert result->>'reason'='admission_invalid', 'other product used admission';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('a',64),'chronospark_credits_100','GPA.public-a',false,
    admission_id,purchased_at);
  assert (result->>'granted')::boolean, 'admitted purchase not granted';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('a',64),'chronospark_credits_100','GPA.public-a',false,
    admission_id,purchased_at);
  assert (result->>'duplicate')::boolean, 'paid retry not idempotent';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('b',64),'chronospark_credits_100','GPA.public-b',false,
    admission_id,purchased_at);
  assert result->>'reason'='admission_invalid', 'admission reused for second sale';
  admission := public.create_public_credit_checkout_admission(a,'chronospark_credits_100');
  admission_id := admission->>'admissionId';
  update public.public_credit_checkout_admissions
    set purchase_deadline=now()-interval '1 minute'
    where id=admission_id::uuid;
  result := public.grant_verified_credit_topup_v2(
    a,repeat('c',64),'chronospark_credits_100','GPA.public-c',false,
    admission_id,purchased_at);
  assert result->>'reason'='admission_invalid', 'expired admission accepted';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('d',64),'chronospark_credits_100','GPA.public-d',false,
    null,purchased_at);
  assert result->>'reason'='admission_missing', 'unadmitted sale accepted';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('e',64),'chronospark_credits_100','GPA.test-e',true,
    null,null);
  assert (result->>'granted')::boolean, 'license-test grant requires public admission';
  assert (select count(*) from public.credit_topup_purchases where
    token_hash in (repeat('a',64),repeat('b',64),repeat('c',64),repeat('d',64),repeat('e',64)))=2,
    'failed or duplicate admissions changed purchased-credit ledger';
end;
$$;
select pass('public checkout admission binds user, product, time, and one receipt');
select * from finish();
rollback;
