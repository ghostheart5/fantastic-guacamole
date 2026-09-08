begin;
create extension if not exists pgtap with schema extensions;
select plan(12);
insert into auth.users(id,email) values
 ('89898989-8989-4989-8989-898989898989','prepaid-regression@example.invalid');
set local role service_role;
select public.bind_verified_purchase_token(repeat('8',64),
 '89898989-8989-4989-8989-898989898989','chronospark_premium_monthly',now(),null);
select public.reconcile_google_play_subscription(repeat('8',64),
 'chronospark_premium_monthly','active',true,true,'prepaid-prior-order',
 now()+interval '1 day',now(),'prepaid:prior',
 '{"source":"client_verification"}'::jsonb);
select public.reconcile_google_play_subscription(repeat('8',64),
 'chronospark_premium_monthly','expired',false,false,'prepaid-prior-order',
 now()-interval '1 second',now()+interval '1 minute','prepaid:prior-expired',
 '{"source":"google_play_rtdn","notificationType":13}'::jsonb);
-- Fixture represents an exhausted free allowance after a historical paid plan.
update public.monetization_wallets set balance=0,allowance_remaining=0,bonus_balance=0
 where user_id='89898989-8989-4989-8989-898989898989';
select public.bind_verified_purchase_token(repeat('9',64),
 '89898989-8989-4989-8989-898989898989','chronospark_premium_monthly',now(),null);
select is((public.reconcile_google_play_subscription(repeat('9',64),
 'chronospark_premium_monthly','active',true,false,'prepaid-new-order',
 now()+interval '1 day',now()+interval '2 minutes','prepaid:first',
 '{"source":"client_verification","basePlanId":"monthly-prepaid-test","prepaidPlan":true,"testPurchase":true}'::jsonb
 )->>'creditsGranted')::integer,300,'fresh verified prepaid purchase fills exhausted allowance');
select is((select balance from public.monetization_wallets where user_id='89898989-8989-4989-8989-898989898989'),300,'server balance is 300');
select is((select count(*)::integer from public.monetization_allowance_grants where purchase_token_hash=repeat('9',64) and grant_cause='prepaid_activation'),1,'one prepaid grant recorded');
select public.reserve_ai_usage('89898989-8989-4989-8989-898989898989','prepaid-test-spend',1,repeat('b',64));
select public.settle_ai_usage('89898989-8989-4989-8989-898989898989','prepaid-test-spend',true);
select is((public.reconcile_google_play_subscription(repeat('9',64),
 'chronospark_premium_monthly','active',true,false,'prepaid-new-order',
 now()+interval '1 day',now()+interval '2 minutes','prepaid:first',
 '{"source":"client_verification","basePlanId":"monthly-prepaid-test","prepaidPlan":true,"testPurchase":true}'::jsonb
 )->>'duplicate')::boolean,true,'identical verification is idempotent');
select is((public.reconcile_google_play_subscription(repeat('9',64),
 'chronospark_premium_monthly','active',true,false,'prepaid-new-order',
 now()+interval '1 day',now()+interval '3 minutes','prepaid:rtdn',
 '{"source":"google_play_rtdn","notificationType":4,"basePlanId":"monthly-prepaid-test","prepaidPlan":true,"testPurchase":true}'::jsonb
 )->>'allowanceGrantReason'),'duplicate_order_id','RTDN delivery does not grant the same order twice');
select is((select balance from public.monetization_wallets where user_id='89898989-8989-4989-8989-898989898989'),299,'restore and RTDN preserve spent balance');
select is((public.reconcile_google_play_subscription(repeat('9',64),
 'chronospark_premium_monthly','active',true,false,'prepaid-another-order',
 now()+interval '1 day',now()+interval '4 minutes','prepaid:changed-order',
 '{"source":"google_play_rtdn","notificationType":4,"basePlanId":"monthly-prepaid-test","prepaidPlan":true,"testPurchase":true}'::jsonb
 )->>'allowanceGrantReason'),'grant_duplicate','same prepaid token cannot refill with a changed order');
select is((select balance from public.monetization_wallets where user_id='89898989-8989-4989-8989-898989898989'),299,'token replay preserves balance');
-- The negative cases have prior allowance history, so no initial grant can hide a failure.
select public.bind_verified_purchase_token(repeat('a',64),'89898989-8989-4989-8989-898989898989','chronospark_premium_monthly',now(),null);
select public.reconcile_google_play_subscription(repeat('a',64),'chronospark_premium_monthly','active',true,false,'prepaid-negative-5',now()+interval '1 day',now()+interval '5 minutes','prepaid:negative:5','{"basePlanId": "monthly-prepaid-test", "prepaidPlan": true, "testPurchase": false, "source": "google_play_rtdn", "notificationType": 4}'::jsonb);
select is((select count(*)::integer from public.monetization_allowance_grants where purchase_token_hash=repeat('a',64)),0,'real purchase is outside internal prepaid grant');
select public.bind_verified_purchase_token(repeat('b',64),'89898989-8989-4989-8989-898989898989','chronospark_premium_monthly',now(),null);
select public.reconcile_google_play_subscription(repeat('b',64),'chronospark_premium_monthly','active',true,false,'prepaid-negative-6',now()+interval '1 day',now()+interval '6 minutes','prepaid:negative:6','{"basePlanId": "monthly", "prepaidPlan": true, "testPurchase": true, "source": "google_play_rtdn", "notificationType": 4}'::jsonb);
select is((select count(*)::integer from public.monetization_allowance_grants where purchase_token_hash=repeat('b',64)),0,'other base plan does not receive prepaid grant');
select public.bind_verified_purchase_token(repeat('c',64),'89898989-8989-4989-8989-898989898989','chronospark_premium_monthly',now(),null);
select public.reconcile_google_play_subscription(repeat('c',64),'chronospark_premium_monthly','active',true,false,'prepaid-negative-7',now()+interval '1 day',now()+interval '7 minutes','prepaid:negative:7','{"basePlanId": "monthly-prepaid-test", "prepaidPlan": false, "testPurchase": true, "source": "google_play_rtdn", "notificationType": 4}'::jsonb);
select is((select count(*)::integer from public.monetization_allowance_grants where purchase_token_hash=repeat('c',64)),0,'missing Google prepaid evidence does not grant');
select public.bind_verified_purchase_token(repeat('d',64),'89898989-8989-4989-8989-898989898989','chronospark_premium_monthly',now(),null);
select public.reconcile_google_play_subscription(repeat('d',64),'chronospark_premium_monthly','pending',false,false,'prepaid-negative-8',now()+interval '1 day',now()+interval '8 minutes','prepaid:negative:8','{"basePlanId": "monthly-prepaid-test", "prepaidPlan": true, "testPurchase": true, "source": "google_play_rtdn", "notificationType": 4}'::jsonb);
select is((select count(*)::integer from public.monetization_allowance_grants where purchase_token_hash=repeat('d',64)),0,'pending purchase does not grant');
reset role;
select * from finish();
rollback;
