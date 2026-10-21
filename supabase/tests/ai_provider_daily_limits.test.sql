-- Disposable PostgreSQL/pgTAP only: every fixture rolls back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(44);
insert into auth.users(id,email) values
 ('83838383-8383-4383-8383-838383838383','daily-provider-a@example.invalid'),
 ('84848484-8484-4484-8484-848484848484','daily-provider-b@example.invalid');
do $$ begin
 perform public.reset_monetization_allowance('83838383-8383-4383-8383-838383838383');
 perform public.reset_monetization_allowance('84848484-8484-4484-8484-848484848484');
end $$;
update public.monetization_wallets set lifetime_earned=100000
where user_id in ('83838383-8383-4383-8383-838383838383','84848484-8484-4484-8484-848484848484');
-- Convenience wrapper only in this rollback-scoped test; production RPC unchanged.
create function pg_temp.budget(amount bigint) returns jsonb language sql volatile as $$
 select public.reserve_ai_repair_budget('83838383-8383-4383-8383-838383838383','daily-cost-current',amount);
$$;
select is((public.reserve_ai_usage('83838383-8383-4383-8383-838383838383','daily-cost-current',5,repeat('a',64))->>'allowed')::boolean,true,'five credits reserve once');
insert into public.ai_usage_requests(billing_principal_id,user_id,request_key,state,credit_amount,prompt_hash,reserved_provider_cost_microusd,accounted_provider_cost_microusd)
select billing_principal_id,user_id,'daily-cost-prior','completed',1,repeat('b',64),15000,585000 from public.monetization_wallets where user_id='83838383-8383-4383-8383-838383838383';
insert into public.ai_usage_requests(billing_principal_id,user_id,request_key,state,credit_amount,prompt_hash,reserved_provider_cost_microusd,accounted_provider_cost_microusd)
select billing_principal_id,user_id,'daily-cost-global','completed',1,repeat('c',64),15000,0 from public.monetization_wallets where user_id='84848484-8484-4484-8484-848484848484';
select is((pg_temp.budget(15000)->>'allowed')::boolean,true,'principal exact600000 boundary counts current once');
select is((pg_temp.budget(15000)->>'duplicate')::boolean,true,'same amount replay has no expansion');
select is(pg_temp.budget(15001)->>'reason','daily_budget_exceeded','principal one microUSD over denied');
select is((select reserved_provider_cost_microusd from public.ai_usage_requests where request_key='daily-cost-current'),15000::bigint,'denial leaves reservation unchanged');
update public.ai_usage_requests set accounted_provider_cost_microusd=584999 where request_key='daily-cost-prior';
select is((pg_temp.budget(15001)->>'allowed')::boolean,true,'only delta1 reaches exact boundary');
update public.ai_usage_requests set accounted_provider_cost_microusd=585000 where request_key='daily-cost-prior';
select is(pg_temp.budget(15000)->>'reason','daily_budget_exceeded','lower amount cannot bypass no-delta cap');
select is(pg_temp.budget(15001)->>'reason','daily_budget_exceeded','same amount cannot bypass no-delta cap');
update public.ai_usage_requests set state='refunded',reserved_provider_cost_microusd=900000,accounted_provider_cost_microusd=0 where request_key='daily-cost-prior';
select is((pg_temp.budget(600000)->>'allowed')::boolean,true,'authoritative refunded zero overrides unused reserved900000');
update public.ai_usage_requests set reserved_provider_cost_microusd=1,accounted_provider_cost_microusd=null where request_key='daily-cost-prior';
select is(pg_temp.budget(600000)->>'reason','daily_budget_exceeded','unknown refund conservatively retains reservation');
update public.ai_usage_requests set reserved_provider_cost_microusd=null where request_key='daily-cost-prior';
select is(pg_temp.budget(600000)->>'reason','daily_budget_exceeded','legacy null costs fall back to credits*3000');
update public.ai_usage_requests set reserved_provider_cost_microusd=1,accounted_provider_cost_microusd=2 where request_key='daily-cost-prior';
select is(pg_temp.budget(600000)->>'reason','daily_budget_exceeded','actual larger than reservation is authoritative');
update public.ai_usage_requests set created_at=now()-interval '24 hours'-interval '1 microsecond' where request_key='daily-cost-prior';
select is((pg_temp.budget(600000)->>'allowed')::boolean,true,'older than24h excluded');
update public.ai_usage_requests set created_at=now()-interval '24 hours' where request_key='daily-cost-prior';
select is(pg_temp.budget(600000)->>'reason','daily_budget_exceeded','exact24h boundary included');
update public.ai_usage_requests set created_at=now(),state='denied',accounted_provider_cost_microusd=900000 where request_key='daily-cost-prior';
select is((pg_temp.budget(600000)->>'allowed')::boolean,true,'denied rows do not book provider work');
update public.ai_usage_requests set state='reserved',accounted_provider_cost_microusd=null,reserved_provider_cost_microusd=1 where request_key='daily-cost-prior';
select is(pg_temp.budget(600000)->>'reason','daily_budget_exceeded','other in-flight reservation books exposure');
update public.ai_usage_requests set state='completed',accounted_provider_cost_microusd=0 where request_key='daily-cost-prior';
-- Other principal contributes to global cap, not this principal cap.
update public.ai_usage_requests set reserved_provider_cost_microusd=15000 where request_key='daily-cost-current';
update public.ai_usage_requests set accounted_provider_cost_microusd=59985000 where request_key='daily-cost-global';
select is((pg_temp.budget(15000)->>'allowed')::boolean,true,'global exact60000000 no-delta boundary allowed');
select is(pg_temp.budget(15001)->>'reason','daily_budget_exceeded','global one microUSD over denied');
update public.ai_usage_requests set accounted_provider_cost_microusd=59984999 where request_key='daily-cost-global';
select is((pg_temp.budget(15001)->>'allowed')::boolean,true,'global exact boundary counts delta, not full amount twice');
update public.ai_usage_requests set accounted_provider_cost_microusd=59985000 where request_key='daily-cost-global';
select is(pg_temp.budget(1)->>'reason','daily_budget_exceeded','global cap checked for lower no-expansion request');
update public.ai_usage_requests set accounted_provider_cost_microusd=0 where request_key='daily-cost-global';
select is((pg_temp.budget(39000)->>'allowed')::boolean,true,'full initial39k funding for five customer credits');
select is((pg_temp.budget(81000)->>'allowed')::boolean,true,'repair reserves initial39k plus repair42k');
select is((select reserved_provider_cost_microusd from public.ai_usage_requests where request_key='daily-cost-current'),81000::bigint,'cumulative budget stored once');
select is((select balance from public.monetization_wallets where user_id='83838383-8383-4383-8383-838383838383'),15,'expansions and denials never redebit wallet');
select is((select count(*) from public.monetization_credit_transactions where user_id='83838383-8383-4383-8383-838383838383' and type='spend'),1::bigint,'one spend ledger row');
select is(public.settle_ai_usage('83838383-8383-4383-8383-838383838383','daily-cost-current',false,0,0)->>'state','refunded','pre-provider failure refunds');
select is((select accounted_provider_cost_microusd from public.ai_usage_requests where request_key='daily-cost-current'),0::bigint,'explicit0/0 accounts zero work');
select is((select balance from public.monetization_wallets where user_id='83838383-8383-4383-8383-838383838383'),20,'five credits restored exactly');
select is((public.reserve_ai_usage('83838383-8383-4383-8383-838383838383','daily-cost-next',5,repeat('d',64))->>'allowed')::boolean,true,'next credit reservation succeeds');
select is((public.reserve_ai_repair_budget('83838383-8383-4383-8383-838383838383','daily-cost-next',600000)->>'allowed')::boolean,true,'knownzero refund releases daily room');
select is(public.settle_ai_usage('83838383-8383-4383-8383-838383838383','daily-cost-next',false)->>'state','refunded','unknown usage failure refunds customer');
select is((select accounted_provider_cost_microusd from public.ai_usage_requests where request_key='daily-cost-next'),600000::bigint,'unknown retains full expanded provider booking');
select is((public.reserve_ai_usage('83838383-8383-4383-8383-838383838383','daily-cost-after-unknown',5,repeat('e',64))->>'allowed')::boolean,true,'credit reservation alone is not dispatch approval');
select is(public.reserve_ai_repair_budget('83838383-8383-4383-8383-838383838383','daily-cost-after-unknown',15000)->>'reason','daily_budget_exceeded','unknown booking blocks next provider approval');
-- Lock mechanism contracts, not a two-connection race/load execution.
select ok(exists(select 1 from pg_catalog.pg_locks where locktype='advisory' and pid=pg_backend_pid() and granted
 and classid=((pg_catalog.hashtextextended('chronospark:ai-daily-budget',0)>>32)&4294967295)::oid
 and objid=(pg_catalog.hashtextextended('chronospark:ai-daily-budget',0)&4294967295)::oid and objsubid=1),'approval holds shared global transaction lock');
select ok(strpos(pg_get_functiondef('public.reserve_ai_repair_budget_for_principal(uuid,text,bigint)'::regprocedure),
 'chronospark:ai-daily-budget') < strpos(pg_get_functiondef('public.reserve_ai_repair_budget_for_principal(uuid,text,bigint)'::regprocedure),
 'into v_principal_daily, v_global_daily'),'global lock precedes rolling aggregate');
select ok(strpos(pg_get_functiondef('public.reserve_ai_repair_budget_for_principal(uuid,text,bigint)'::regprocedure),
 'v_global_daily + v_delta > 60000000') < strpos(pg_get_functiondef('public.reserve_ai_repair_budget_for_principal(uuid,text,bigint)'::regprocedure),
 'if p_required_provider_cost_microusd <= v_current_reserved'),'cap checks precede duplicate allowed return');
select ok(pg_get_functiondef('public.reserve_ai_usage_for_principal(uuid,text,integer,text)'::regprocedure) like '%chronospark:ai-daily-budget%','initial credit reservation shares global lock');
select ok(not (select prosecdef from pg_catalog.pg_proc where oid='public.reserve_ai_repair_budget_for_principal(uuid,text,bigint)'::regprocedure),'security invoker preserved');
select ok(has_function_privilege('service_role','public.reserve_ai_repair_budget_for_principal(uuid,text,bigint)','execute'),'service execute retained');
select ok(not has_function_privilege('anon','public.reserve_ai_repair_budget_for_principal(uuid,text,bigint)','execute') and not has_function_privilege('authenticated','public.reserve_ai_repair_budget_for_principal(uuid,text,bigint)','execute'),'client execute denied');
select is(pg_temp.budget(15000)->>'reason','request_refunded','terminal reservation cannot regain permission');
update public.ai_usage_requests set created_at=now()-interval '25 hours' where user_id='83838383-8383-4383-8383-838383838383' and request_key<>'daily-cost-after-unknown';
update public.monetization_wallets set lifetime_earned=20 where user_id='83838383-8383-4383-8383-838383838383';
select is(public.reserve_ai_repair_budget('83838383-8383-4383-8383-838383838383','daily-cost-after-unknown',39000)->>'reason','provider_cost_budget_exceeded','lifetime guard still includes older provider cost');
update public.billing_principals set current_user_id=null where current_user_id='83838383-8383-4383-8383-838383838383';
select is(public.reserve_ai_repair_budget_for_principal((select billing_principal_id from public.ai_usage_requests where request_key='daily-cost-after-unknown'),'daily-cost-after-unknown',39000)->>'reason','account_detached','detached account denied');
select * from finish();
rollback;
