-- Approved USD catalog prices for Google Play license testing.
-- Keep allowance metadata aligned with the existing server-authoritative
-- 300/360 grant per verified paid period. No wallet or entitlement is changed.
do $$
declare
  changed integer;
begin
  update public.monetization_subscription_plans
  set price_micros = case id
        when 'premium_monthly' then 4990000
        when 'premium_yearly' then 39990000
      end,
      credits_per_period = case id
        when 'premium_monthly' then 300
        when 'premium_yearly' then 360
      end,
      updated_at = now()
  where currency_code = 'USD' and plan_type = 'subscription'
    and ((id = 'premium_monthly' and product_id = 'chronospark_premium_monthly')
      or (id = 'premium_yearly' and product_id = 'chronospark_premium_annual'));
  get diagnostics changed = row_count;
  if changed <> 2 then
    raise exception 'Expected the two established USD subscription catalog rows';
  end if;
end;
$$;
