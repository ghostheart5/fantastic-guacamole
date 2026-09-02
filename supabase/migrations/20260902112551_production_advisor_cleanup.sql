-- Resolve the actionable production Advisor findings found after the
-- 2026-09-02 protected-main deployment. The two tables are currently empty,
-- so these covering indexes do not impose a material production lock.
create index if not exists ai_usage_budget_windows_user_id_idx
  on public.ai_usage_budget_windows (user_id);

create index if not exists monetization_provider_recheck_queue_principal_idx
  on public.monetization_provider_recheck_queue (billing_principal_id);

-- These pairs have identical authenticated SELECT predicates. Retain one
-- policy per table so Postgres does not evaluate duplicate permissive rules.
drop policy if exists "ai usage select own"
  on public.ai_usage_requests;

drop policy if exists "monetization_subscription_statuses_select_own"
  on public.monetization_subscription_statuses;

drop policy if exists "monetization_wallets_select_own"
  on public.monetization_wallets;
