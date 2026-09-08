begin;
select '1..1';
insert into auth.users(id,email) values ('73737373-7373-4373-8373-737373737373','returning-credit@example.invalid');
set local role service_role;
do $$
declare
 u constant uuid := '73737373-7373-4373-8373-737373737373';
 r jsonb; w public.monetization_wallets;
 proof jsonb := '{"source":"client_verification","testPurchase":true,"prepaidPlan":false,"basePlanId":"monthly"}';
begin
 perform public.bind_verified_purchase_token(repeat('7',64),u,'chronospark_premium_monthly',now(),null);
 perform public.reconcile_google_play_subscription(repeat('7',64),'chronospark_premium_monthly','active',true,true,'returning-old',now()+interval '1 day',now(),'returning:old','{"source":"client_verification"}');
 perform public.reconcile_google_play_subscription(repeat('7',64),'chronospark_premium_monthly','expired',false,false,'returning-old',now()-interval '1 second',now()+interval '1 minute','returning:expired','{"source":"google_play_rtdn","notificationType":13}');
 update public.monetization_wallets set allowance_remaining=0,balance=0 where user_id=u;
 perform public.grant_verified_credit_topup(u,repeat('6',64),'chronospark_credits_100','returning-pack');
 perform public.bind_verified_purchase_token(repeat('8',64),u,'chronospark_premium_monthly',now()+interval '1 second',null);
 perform public.reconcile_google_play_subscription(repeat('8',64),'chronospark_premium_monthly','pending',false,true,'returning-new',now()+interval '1 month',now()+interval '2 minutes','returning:pending',proof);
 assert (select balance=100 from public.monetization_wallets where user_id=u),'pending never grants';
 perform public.reconcile_google_play_subscription(repeat('8',64),'chronospark_premium_monthly','active',true,true,'returning-new',now()+interval '1 month',now()+interval '3 minutes','returning:no-test',proof||'{"testPurchase":false}');
 assert (select balance=100 from public.monetization_wallets where user_id=u),'private policy requires test proof';
 r:=public.reconcile_google_play_subscription(repeat('8',64),'chronospark_premium_monthly','active',true,true,'returning-new',now()+interval '1 month',now()+interval '4 minutes','returning:verified',proof);
 select * into w from public.monetization_wallets where user_id=u;
 assert w.balance=400 and w.allowance_remaining=300 and w.bonus_balance=100,'fresh returning purchase grants 300 and preserves purchased credits';
 assert w.funded_until>now()+interval '27 days','paid funding established';
 perform public.reserve_ai_usage(u,'returning-spend',3,repeat('a',64));
 perform public.settle_ai_usage(u,'returning-spend',true,100,100);
 perform public.reconcile_google_play_subscription(repeat('8',64),'chronospark_premium_monthly','active',true,true,'returning-new',now()+interval '1 month',now()+interval '5 minutes','returning:restore',proof);
 perform public.reconcile_google_play_subscription(repeat('8',64),'chronospark_premium_monthly','active',true,true,'returning-new',now()+interval '1 month',now()+interval '6 minutes','returning:rtdn',proof||'{"source":"google_play_rtdn","notificationType":4}');
 perform public.reconcile_google_play_subscription(repeat('8',64),'chronospark_premium_monthly','active',true,true,'returning-changed-order',now()+interval '1 month',now()+interval '7 minutes','returning:changed',proof);
 assert (select balance=397 and allowance_remaining=297 and bonus_balance=100 from public.monetization_wallets where user_id=u),'restore, RTDN and changed-order replay do not refill';
 assert (select count(*)=1 from public.monetization_allowance_grants where purchase_token_hash=repeat('8',64)),'one activation per token';
end;
$$;
select 'ok 1 - returning paid subscription allowance and replay boundaries';
rollback;
