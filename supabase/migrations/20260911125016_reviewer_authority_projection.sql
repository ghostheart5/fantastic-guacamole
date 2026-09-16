-- Keep purchase identifiers and internal metadata private. Existing owner RLS
-- also applies to these four non-secret entitlement fields.
grant select (source,started_at,auto_renews,period_credits)
  on public.monetization_subscription_statuses to authenticated;
