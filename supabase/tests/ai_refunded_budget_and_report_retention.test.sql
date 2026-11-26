-- Disposable PostgreSQL/pgTAP only: every fixture rolls back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users(id, email) values
 ('85858585-8585-4585-8585-858585858585', 'refunded-budget@example.invalid'),
 ('86868686-8686-4686-8686-868686868686', 'report-retention@example.invalid');
do $$ begin
 perform public.reset_monetization_allowance('85858585-8585-4585-8585-858585858585');
end $$;
update public.monetization_wallets set lifetime_earned = 100000
where user_id = '85858585-8585-4585-8585-858585858585';

-- 190 credits completed and a refunded 50-credit request, all inside 24 hours.
insert into public.ai_usage_requests(
  billing_principal_id, user_id, request_key, state, credit_amount, prompt_hash,
  reserved_provider_cost_microusd, accounted_provider_cost_microusd
)
select billing_principal_id, user_id, 'budget-completed-1', 'completed', 100,
  repeat('a', 64), 300000, 0
from public.monetization_wallets
where user_id = '85858585-8585-4585-8585-858585858585';
insert into public.ai_usage_requests(
  billing_principal_id, user_id, request_key, state, credit_amount, prompt_hash,
  reserved_provider_cost_microusd, accounted_provider_cost_microusd
)
select billing_principal_id, user_id, 'budget-completed-2', 'completed', 90,
  repeat('b', 64), 270000, 0
from public.monetization_wallets
where user_id = '85858585-8585-4585-8585-858585858585';
insert into public.ai_usage_requests(
  billing_principal_id, user_id, request_key, state, credit_amount, prompt_hash,
  reserved_provider_cost_microusd, accounted_provider_cost_microusd
)
select billing_principal_id, user_id, 'budget-refunded-1', 'refunded', 50,
  repeat('c', 64), 150000, 150000
from public.monetization_wallets
where user_id = '85858585-8585-4585-8585-858585858585';

select is(
  (public.reserve_ai_usage(
    '85858585-8585-4585-8585-858585858585', 'budget-new-request-1', 5,
    repeat('d', 64)
  )->>'allowed')::boolean,
  true,
  'a refunded request does not count toward the 200-credit daily budget'
);
select is(
  public.reserve_ai_usage(
    '85858585-8585-4585-8585-858585858585', 'budget-new-request-2', 6,
    repeat('e', 64)
  )->>'reason',
  'daily_budget_exceeded',
  'completed and reserved credits still stop at 200 (190 + 5 + 6)'
);
select is(
  (select credit_amount from public.ai_usage_requests
   where request_key = 'budget-refunded-1'),
  50,
  'the refunded row is kept; only its daily-credit weight is removed'
);
select ok(
  pg_get_functiondef(
    'public.reserve_ai_usage_for_principal(uuid,text,integer,text)'::regprocedure
  ) not like '%''reserved'', ''completed'', ''refunded''%',
  'the credit budget no longer lists refunded'
);
select ok(
  pg_get_functiondef(
    'public.reserve_ai_repair_budget_for_principal(uuid,text,bigint)'::regprocedure
  ) like '%''reserved'', ''completed'', ''refunded''%',
  'provider-cost budget still counts refunded work, which bounds free model calls'
);

insert into public.ai_content_reports(user_id, reason, content, source, created_at)
values
 ('86868686-8686-4686-8686-868686868686', 'other', 'old reply text', 'chat',
  now() - interval '181 days'),
 ('86868686-8686-4686-8686-868686868686', 'other', 'recent reply text',
  'si_console', now() - interval '179 days');

select throws_ok(
  $$select public.purge_expired_ai_content_reports(interval '1 day')$$,
  'AI report retention must be at least 30 days',
  'a short retention period is refused'
);
select is(
  public.purge_expired_ai_content_reports(interval '180 days'),
  1,
  'one report older than 180 days is scrubbed'
);
select is(
  (select content from public.ai_content_reports where source = 'chat'),
  '[removed after retention period]',
  'the old reply text is replaced'
);
select is(
  (select content from public.ai_content_reports where source = 'si_console'),
  'recent reply text',
  'a report inside the period is untouched'
);
select is(
  (select reason || ':' || status from public.ai_content_reports
   where source = 'chat'),
  'other:new',
  'reason and status survive the scrub'
);
select is(
  public.purge_expired_ai_content_reports(interval '180 days'),
  0,
  'a second run changes nothing'
);
select ok(
  has_function_privilege(
    'service_role', 'public.purge_expired_ai_content_reports(interval)',
    'execute'
  ) and not has_function_privilege(
    'authenticated', 'public.purge_expired_ai_content_reports(interval)',
    'execute'
  ) and not has_function_privilege(
    'anon', 'public.purge_expired_ai_content_reports(interval)', 'execute'
  ),
  'only the server role can run the purge'
);
select ok(
  exists(
    select 1 from cron.job
    where jobname = 'axiomara-purge-ai-content-reports'
      and command like '%180 days%'
  ),
  'the daily retention job is scheduled'
);

select * from finish();
rollback;
