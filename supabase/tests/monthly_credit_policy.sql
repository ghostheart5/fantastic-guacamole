-- Runs against an isolated database. Every fixture is rolled back.
begin;
select '1..1';
insert into auth.users(id,email) values
 ('71717171-7171-4171-8171-717171717171','credit-policy-a@example.invalid'),
 ('72727272-7272-4272-8272-727272727272','credit-policy-b@example.invalid');
set local role service_role;
do $$
declare
  a constant uuid := '71717171-7171-4171-8171-717171717171';
  b constant uuid := '72727272-7272-4272-8272-727272727272';
  principal uuid; wallet public.monetization_wallets; result jsonb;
begin
  assert public.credit_month_boundary('2024-01-31 12:00Z',1)='2024-02-29 12:00Z'::timestamptz,'leap month boundary';
  assert public.credit_month_boundary('2024-01-31 12:00Z',2)='2024-03-31 12:00Z'::timestamptz,'anchor does not drift';
  wallet:=public.reset_monetization_allowance(a);
  principal:=wallet.billing_principal_id;
  assert wallet.balance=20 and wallet.period_ends_at>now()+interval '27 days','free monthly initialization';
  result:=public.grant_verified_credit_topup(a,repeat('1',64),'chronospark_credits_100','policy-topup-1');
  assert (result->>'granted')::boolean and (result->>'balance')::int=120,'100 topup granted';
  result:=public.grant_verified_credit_topup(a,repeat('1',64),'chronospark_credits_100','policy-topup-1');
  assert (result->>'duplicate')::boolean,'duplicate topup idempotent';
  result:=public.grant_verified_credit_topup(b,repeat('1',64),'chronospark_credits_100','policy-topup-1');
  assert result->>'reason'='ownership_mismatch','cross-account receipt rejected';
  result:=public.reserve_ai_usage(a,'policy-spend-01',10,repeat('a',64));
  assert (result->>'allowed')::boolean,'variable credit amount accepted';
  select * into wallet from public.monetization_wallets where billing_principal_id=principal;
  assert wallet.allowance_remaining=10 and wallet.bonus_balance=100,'monthly allowance spent before purchased';
  perform public.settle_ai_usage(a,'policy-spend-01',true,100,100);
  perform public.reserve_ai_usage(a,'policy-spend-02',15,repeat('b',64));
  select * into wallet from public.monetization_wallets where billing_principal_id=principal;
  assert wallet.allowance_remaining=0 and wallet.bonus_balance=95,'spending crosses balance buckets correctly';
  perform public.settle_ai_usage(a,'policy-spend-02',false,0,0,null,'test_failure');
  select * into wallet from public.monetization_wallets where billing_principal_id=principal;
  assert wallet.allowance_remaining=10 and wallet.bonus_balance=100,'failed request restores original buckets';
  perform public.settle_ai_usage(a,'policy-spend-02',false);
  assert (select balance=110 from public.monetization_wallets where billing_principal_id=principal),'repeated refund does not mint credits';
  update public.monetization_wallets set allowance_anchor=now()-interval '3 months',allowance_index=0,
    period_ends_at=now()-interval '2 months' where billing_principal_id=principal;
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.balance=120 and wallet.bonus_balance=100,'missed free months do not accumulate; topup preserved';
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.balance=120,'repeat monthly read does not refill';
  perform public.revoke_verified_credit_topup(repeat('1',64),'chronospark_credits_100','policy-topup-1');
  assert (select balance=20 and bonus_balance=0 from public.monetization_wallets where billing_principal_id=principal),'refund revokes only topup balance';
  result:=public.grant_verified_credit_topup(a,repeat('1',64),'chronospark_credits_100','policy-topup-1');
  assert not (result->>'granted')::boolean,'revoked receipt cannot regrant';
  perform public.revoke_verified_credit_topup(repeat('2',64),'chronospark_credits_300','policy-topup-2');
  result:=public.grant_verified_credit_topup(a,repeat('2',64),'chronospark_credits_300','policy-topup-2');
  assert not (result->>'granted')::boolean,'revoke-before-verify prevents grant';
  perform public.bind_verified_purchase_token(repeat('3',64),a,'chronospark_premium_annual',now(),null);
  result:=public.reconcile_google_play_subscription(repeat('3',64),'chronospark_premium_annual',
    'active',true,true,'policy-annual-1',now()+interval '1 year',now(),'policy:annual:initial','{"source":"client_verification"}'::jsonb);
  select * into wallet from public.monetization_wallets where billing_principal_id=principal;
  assert wallet.period_credits=300 and wallet.allowance_remaining=300,'annual grants 300';
  assert (select period_credits=300 from public.monetization_subscription_statuses where billing_principal_id=principal),'annual status matches monthly 300 allowance';
  assert wallet.tier='premium_yearly' and wallet.funded_until>now()+interval '360 days','annual identity and paid coverage retained';
  assert wallet.period_ends_at<now()+interval '32 days','annual wallet expires monthly';
  perform public.reserve_ai_usage(a,'policy-annual-spend',5,repeat('c',64));
  perform public.settle_ai_usage(a,'policy-annual-spend',true,100,100);
  result:=public.reconcile_google_play_subscription(repeat('3',64),'chronospark_premium_annual',
    'active',true,true,'policy-annual-1',now()+interval '1 year',now()+interval '1 second','policy:annual:restore','{"source":"client_verification"}'::jsonb);
  assert (select allowance_remaining=295 from public.monetization_wallets where billing_principal_id=principal),'restore does not refill';
  update public.monetization_wallets set allowance_anchor=now()-interval '1 month',allowance_index=0,period_ends_at=now()-interval '1 second' where billing_principal_id=principal;
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.allowance_remaining=300 and wallet.allowance_index=1,'annual paid coverage funds next monthly window';
  update public.monetization_wallets set allowance_remaining=7,balance=7,period_ends_at=now()-interval '1 second' where billing_principal_id=principal;
  update public.monetization_subscription_statuses set status='grace' where billing_principal_id=principal;
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.balance=7,'grace does not add allowance';
  perform public.grant_verified_credit_topup(a,repeat('4',64),'chronospark_credits_100','policy-topup-4');
  update public.monetization_subscription_statuses set status='expired',is_active=false,auto_renews=false where billing_principal_id=principal;
  wallet:=public.reset_monetization_allowance(a);
  assert wallet.bonus_balance=100 and wallet.tier='free','purchased credits survive subscription expiry';
  wallet:=public.reset_monetization_allowance(b);
  perform public.grant_verified_credit_topup(b,repeat('5',64),'chronospark_credits_100','policy-topup-5');
  perform public.reserve_ai_usage(b,'policy-refund-race',30,repeat('e',64));
  perform public.revoke_verified_credit_topup(repeat('5',64),'chronospark_credits_100','policy-topup-5');
  assert (select refunded_credit_debt=10 and bonus_balance=0 from public.monetization_wallets where user_id=b),'refund of in-flight purchased credits creates a bounded debt';
  perform public.settle_ai_usage(b,'policy-refund-race',false);
  assert (select refunded_credit_debt=0 and bonus_balance=0 and balance=20 from public.monetization_wallets where user_id=b),'failed in-flight request reverses debt without restoring revoked credits';
  perform public.reserve_ai_usage(b,'policy-old-window',5,repeat('e',64));
  update public.ai_usage_requests set funding_period_ends_at=now()-interval '1 second' where user_id=b and request_key='policy-old-window';
  update public.monetization_wallets set allowance_anchor=now()-interval '1 month',period_ends_at=now()-interval '1 second' where user_id=b;
  perform public.reset_monetization_allowance(b);
  perform public.settle_ai_usage(b,'policy-old-window',false);
  assert (select balance=20 from public.monetization_wallets where user_id=b),'expired monthly allowance cannot return into the new month';
  perform public.revoke_verified_credit_topup(repeat('6',64),null,'policy-voided-before-verify');
  result:=public.grant_verified_credit_topup(b,repeat('6',64),'chronospark_credits_300','policy-voided-before-verify');
  assert not (result->>'granted')::boolean,'voided notification without SKU blocks later grant';
  assert (public.credit_topup_owner(encode(extensions.digest(b::text,'sha256'),'hex'))->>'userId')::uuid=b,'delayed purchase resolves the bound active account';
  assert not has_function_privilege('anon','public.grant_verified_credit_topup(uuid,text,text,text)','execute'),'anonymous cannot grant';
  assert not has_function_privilege('authenticated','public.grant_verified_credit_topup(uuid,text,text,text)','execute'),'client cannot grant itself';
  assert not has_function_privilege('anon','public.get_credit_wallet_v2()','execute'),'wallet requires signed-in account';
  raise notice 'PASS: monthly allowance, purchase, ownership, refund and permission assertions';
end;
$$;
select 'ok 1 - monthly credit policy assertions passed';
rollback;
