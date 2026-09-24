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
  assert not has_function_privilege('authenticated',
    'public.register_verified_pending_credit_topup(uuid,text,text,text)', 'execute'),
    'app clients cannot bind pending Google tokens';
  assert not has_function_privilege('authenticated',
    'public.queue_unadmitted_credit_topup(uuid,text,text,text)', 'execute'),
    'app clients cannot invent paid-order resolutions';
  assert not has_table_privilege('authenticated',
    'public.public_credit_checkout_resolutions', 'select'),
    'app clients cannot inspect paid-order resolution records';
  result := public.create_public_credit_checkout_admission(a,null);
  assert result->>'reason'='invalid_product',
    'null product reached admission lock or insert';
  admission := public.create_public_credit_checkout_admission(a,'chronospark_credits_100');
  assert (admission->>'allowed')::boolean, 'server could not create admission';
  admission_id := admission->>'admissionId';
  result := public.create_public_credit_checkout_admission(a,'chronospark_credits_100');
  assert result->>'admissionId'=admission_id,
    'repeated eligibility created another unused admission';
  assert (select count(*) from public.public_credit_checkout_admissions
    where billing_principal_id=public.ensure_billing_principal(a)
      and product_id='chronospark_credits_100'
      and pending_token_hash is null and consumed_token_hash is null
      and retired_at is null)=1,
    'more than one live unused admission was stockpiled';
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
    set issued_at=now()+interval '1 day'
    where id=admission_id::uuid;
  result := public.grant_verified_credit_topup_v2(
    a,repeat('c',64),'chronospark_credits_100','GPA.public-c',false,
    admission_id,purchased_at);
  assert result->>'reason'='admission_invalid', 'pre-admission purchase accepted';
  update public.public_credit_checkout_admissions
    set issued_at=now()-interval '3 days'
    where id=admission_id::uuid;
  result := public.grant_verified_credit_topup_v2(
    a,repeat('c',64),'chronospark_credits_100','GPA.public-c',false,
    admission_id,purchased_at);
  assert result->>'reason'='customer_resolution_required' and
    (result->>'resolutionQueued')::boolean,
    'stockpiled unused admission authorized a new purchase or lost its order';
  assert (select count(*) from public.public_credit_checkout_resolutions
    where token_hash=repeat('c',64) and order_id='GPA.public-c'
      and state='awaiting_resolution')=1,
    'unfulfilled verified paid order was not durably queued';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('c',64),'chronospark_credits_100','GPA.public-c',false,
    admission_id,purchased_at);
  assert result->>'reason'='customer_resolution_required' and
    (select count(*) from public.public_credit_checkout_resolutions
      where token_hash=repeat('c',64))=1,
    'retry did not retain exactly one resolution record';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('c',64),'chronospark_credits_100','GPA.other',false,
    admission_id,purchased_at);
  assert result->>'reason'='resolution_proof_mismatch',
    'resolution token was reused with a different order';
  result := public.revoke_verified_credit_topup(
    repeat('c',64),'chronospark_credits_100','GPA.public-c');
  assert (result->>'handled')::boolean and
    (select state from public.public_credit_checkout_resolutions
      where token_hash=repeat('c',64))='refunded',
    'voided unfulfilled payment remained actionable in the resolution queue';
  result := public.revoke_verified_credit_topup(
    repeat('c',64),'chronospark_credits_100','GPA.public-c');
  assert (result->>'duplicate')::boolean and
    (select state from public.public_credit_checkout_resolutions
      where token_hash=repeat('c',64))='refunded',
    'duplicate void reopened a refunded resolution';
  admission := public.create_public_credit_checkout_admission(a,'chronospark_credits_100');
  assert admission->>'admissionId'<>admission_id,
    'expired unused admission was returned for a new checkout';
  admission_id := admission->>'admissionId';
  result := public.register_verified_pending_credit_topup(
    b,repeat('f',64),'chronospark_credits_100',admission_id);
  assert result->>'reason'='admission_invalid',
    'other account registered a pending token';
  result := public.register_verified_pending_credit_topup(
    a,repeat('f',64),'chronospark_credits_300',admission_id);
  assert result->>'reason'='admission_invalid',
    'other product registered a pending token';
  result := public.register_verified_pending_credit_topup(
    a,repeat('f',64),'chronospark_credits_100',admission_id);
  assert (result->>'registered')::boolean,
    'verified pending token was not bound';
  result := public.register_verified_pending_credit_topup(
    a,repeat('f',64),'chronospark_credits_100',admission_id);
  assert (result->>'duplicate')::boolean,
    'verified pending token retry was not idempotent';
  update public.public_credit_checkout_admissions
    set issued_at=now()-interval '3 days',
        pending_verified_at=now()-interval '3 days'+interval '5 minutes'
    where id=admission_id::uuid;
  result := public.grant_verified_credit_topup_v2(
    a,repeat('1',64),'chronospark_credits_100','GPA.public-g',false,
    admission_id,purchased_at);
  assert result->>'reason'='admission_invalid',
    'pending binding was used by a different token';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('f',64),'chronospark_credits_100','GPA.public-f',false,
    admission_id,purchased_at);
  assert (result->>'granted')::boolean,
    'payment completed after a timely verified pending binding was not granted';
  admission := public.create_public_credit_checkout_admission(b,'chronospark_credits_300');
  admission_id := admission->>'admissionId';
  update public.public_credit_checkout_admissions
    set issued_at=now()-interval '3 days',
        retired_at=now()-interval '2 days'
    where id=admission_id::uuid;
  perform public.purge_expired_public_credit_checkout_admissions();
  assert not exists (select 1 from public.public_credit_checkout_admissions
    where id=admission_id::uuid), 'expired unbound admission was not purged';
  result := public.grant_verified_credit_topup_v2(
    b,repeat('3',64),'chronospark_credits_300','GPA.purged',false,
    admission_id,purchased_at);
  assert result->>'reason'='customer_resolution_required' and
    (result->>'resolutionQueued')::boolean,
    'paid order arriving after admission purge was lost';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('d',64),'chronospark_credits_100','GPA.public-d',false,
    null,purchased_at);
  assert result->>'reason'='admission_missing', 'unadmitted sale accepted';
  result := public.queue_unadmitted_credit_topup(
    a,repeat('2',64),'chronospark_credits_100','GPA.missing');
  assert (result->>'resolutionQueued')::boolean,
    'verified paid order without admission was silently lost';
  result := public.queue_unadmitted_credit_topup(
    a,repeat('2',64),'chronospark_credits_100','GPA.missing');
  assert (result->>'duplicate')::boolean,
    'unadmitted paid-order retry created another resolution';
  result := public.queue_unadmitted_credit_topup(
    b,repeat('2',64),'chronospark_credits_100','GPA.missing');
  assert result->>'reason'='resolution_proof_mismatch',
    'other account reused an unfulfilled paid token';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('2',64),'chronospark_credits_100','GPA.missing',false,
    admission_id,purchased_at);
  assert result->>'reason'='customer_resolution_required',
    'later admission granted a queued unfulfilled order';
  result := public.grant_verified_credit_topup_v2(
    a,repeat('e',64),'chronospark_credits_100','GPA.test-e',true,
    null,null);
  assert (result->>'granted')::boolean, 'license-test grant requires public admission';
  assert (select count(*) from public.credit_topup_purchases where
    token_hash in (repeat('a',64),repeat('b',64),repeat('c',64),repeat('d',64),repeat('e',64),repeat('f',64),repeat('1',64),repeat('2',64),repeat('3',64)))=3,
    'failed or duplicate admissions changed purchased-credit ledger';
end;
$$;
select pass('public checkout admission reuses and purges unused rows without losing delayed payment');
select * from finish();
rollback;
