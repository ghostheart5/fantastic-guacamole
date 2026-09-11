-- Disposable database fixtures; no reviewer or customer data survives this test.
begin;
select '1..1';
insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
 ('81818181-8181-4181-8181-818181818181','review-a@example.invalid',now(),false),
 ('82828282-8282-4282-8282-828282828282','review-b@example.invalid',now(),false),
 ('83838383-8383-4383-8383-838383838383','review-unconfirmed@example.invalid',null,false);
set local role service_role;
do $$
declare
  a constant uuid := '81818181-8181-4181-8181-818181818181';
  b constant uuid := '82828282-8282-4282-8282-828282828282';
  c constant uuid := '83838383-8383-4383-8383-838383838383';
  result jsonb; wallet public.monetization_wallets; rejected boolean;
  grant_expiry timestamptz := now()+interval '30 days';
begin
  assert not has_function_privilege('anon','public.grant_complimentary_review_access(uuid,text,integer,timestamptz)','execute'), 'anonymous cannot self-grant';
  assert not has_function_privilege('authenticated','public.grant_complimentary_review_access(uuid,text,integer,timestamptz)','execute'), 'signed-in clients cannot self-grant';
  assert has_function_privilege('service_role','public.grant_complimentary_review_access(uuid,text,integer,timestamptz)','execute'), 'service authority can grant';
  rejected:=false;
  begin perform public.grant_complimentary_review_access(c,'review:unconfirmed',300,grant_expiry);
  exception when raise_exception then rejected:=true; end;
  assert rejected,'unconfirmed account rejected';
  rejected:=false;
  begin perform public.grant_complimentary_review_access(a,'review:too-long-grant',300,now()+interval '32 days');
  exception when raise_exception then rejected:=true; end;
  assert rejected,'grant duration bounded';
  rejected:=false;
  begin perform public.grant_complimentary_review_access(a,'review:too-many-credits',1001,grant_expiry);
  exception when raise_exception then rejected:=true; end;
  assert rejected,'credit budget bounded';
  result:=public.grant_complimentary_review_access(a,'review:contract-first',300,grant_expiry);
  assert (result->>'granted')::boolean,'review grant succeeds';
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.balance=300 and wallet.allowance_remaining=300 and wallet.period_credits=0,'one-time credit budget';
  assert wallet.funded_until is null,'not paid coverage';
  assert (select status='review_access' and source='complimentary_review' and is_active
    and not auto_renews and period_credits=0 and purchase_token_hash is null and order_id is null
    from public.monetization_subscription_statuses where user_id=a),'explicit non-purchase entitlement';
  assert not exists(select 1 from public.purchase_bindings where billing_principal_id=wallet.billing_principal_id),'no fabricated Play binding';
  result:=public.reserve_ai_usage(a,'review-contract-spend',10,repeat('a',64));
  assert (result->>'allowed')::boolean,'review allowance can fund a normal reservation';
  perform public.settle_ai_usage(a,'review-contract-spend',true,100,100);
  result:=public.grant_complimentary_review_access(a,'review:contract-first',300,now()+interval '31 days');
  assert (result->>'duplicate')::boolean and (result->>'creditsGranted')::int=0,'repeat grant idempotent';
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.balance=290 and wallet.period_ends_at=grant_expiry,'repeat does not refill or extend';
  rejected:=false;
  begin perform public.grant_complimentary_review_access(b,'review:contract-first',300,grant_expiry);
  exception when raise_exception then rejected:=true; end;
  assert rejected,'grant key cannot cross accounts';
  rejected:=false;
  begin perform public.grant_complimentary_review_access(a,'review:overlapping-grant',300,grant_expiry);
  exception when raise_exception then rejected:=true; end;
  assert rejected,'active grant cannot be replaced';
  update public.monetization_wallets set balance=0,allowance_remaining=0,period_ends_at=now()-interval '1 second' where user_id=a;
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.balance=0,'review allowance never renews';
  result:=public.reserve_ai_usage(a,'review-contract-empty',1,repeat('b',64));
  assert not (result->>'allowed')::boolean,'exhaustion blocks normal reservation';
  update public.monetization_wallets set balance=12,allowance_remaining=12,period_ends_at=grant_expiry where user_id=a;
  update public.monetization_subscription_statuses set expires_at=now()-interval '1 second' where user_id=a;
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.balance=0 and wallet.tier='free','expiry removes unused allowance';
  assert (select not is_active and status='expired' from public.monetization_subscription_statuses where user_id=a),'expiry closes access';
  result:=public.grant_complimentary_review_access(a,'review:contract-second',100,grant_expiry);
  assert (result->>'granted')::boolean,'new explicit grant after expiry allowed';
  result:=public.reserve_ai_usage(a,'review-contract-revoke-race',5,repeat('c',64));
  assert (result->>'allowed')::boolean,'in-flight request before revocation';
  update public.monetization_subscription_statuses set status='revoked',is_active=false where user_id=a;
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.balance=0 and wallet.tier='free','revocation before end removes allowance';
  perform public.settle_ai_usage(a,'review-contract-revoke-race',false);
  assert (select balance=0 from public.monetization_wallets where user_id=a),'in-flight failure cannot resurrect revoked allowance';
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.balance=0,'repeated revocation cannot refill';
  perform public.bind_verified_purchase_token(repeat('8',64),b,'chronospark_premium_monthly',now(),null);
  rejected:=false;
  begin perform public.grant_complimentary_review_access(b,'review:customer-protected',300,grant_expiry);
  exception when raise_exception then rejected:=true; end;
  assert rejected,'customer purchase ownership is protected';
end;
$$;
reset role;
select 'ok 1 - bounded complimentary access, ownership, budget, expiry and privileges';
rollback;
