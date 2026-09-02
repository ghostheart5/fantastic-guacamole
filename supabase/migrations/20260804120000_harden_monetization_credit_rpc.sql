-- Keep authenticated credit consumption atomic while preserving RLS for reads.
-- Other wallet mutation helpers remain server-only.

create or replace function public.grant_monetization_credits(
  target_user_id uuid,
  credit_amount integer,
  transaction_type text,
  transaction_source text,
  transaction_description text,
  metadata jsonb default '{}'::jsonb
)
returns public.monetization_wallets
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  wallet_row public.monetization_wallets;
begin
  if target_user_id is null then
    raise exception 'target user required';
  end if;
  if credit_amount is null or credit_amount <= 0 or credit_amount > 5000 then
    raise exception 'credit amount must be between 1 and 5000';
  end if;
  if transaction_type is null or btrim(transaction_type) = '' or
      transaction_source is null or btrim(transaction_source) = '' or
      transaction_description is null or btrim(transaction_description) = '' then
    raise exception 'transaction details are required';
  end if;
  if metadata is null or jsonb_typeof(metadata) <> 'object' or
      pg_column_size(metadata) > 8192 then
    raise exception 'metadata must be an object no larger than 8192 bytes';
  end if;

  perform public.ensure_monetization_wallet(target_user_id);

  update public.monetization_wallets
  set bonus_balance = bonus_balance + credit_amount,
      balance = balance + credit_amount,
      lifetime_earned = lifetime_earned + credit_amount,
      updated_at = now()
  where user_id = target_user_id
  returning * into wallet_row;

  insert into public.monetization_credit_transactions (
    user_id, type, amount, balance_after, source, description, metadata
  )
  values (
    target_user_id, transaction_type, credit_amount, wallet_row.balance,
    transaction_source, transaction_description, metadata
  );

  return wallet_row;
end;
$$;
create or replace function public.consume_monetization_credits(
  credit_amount integer,
  reason text,
  metadata jsonb default '{}'::jsonb
)
returns table (
  allowed boolean,
  balance integer,
  allowance_remaining integer,
  bonus_balance integer,
  period_credits integer,
  lifetime_earned integer,
  lifetime_spent integer,
  tier text,
  updated_at timestamptz,
  period_ends_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_user_id uuid := auth.uid();
  wallet_row public.monetization_wallets;
  active_status public.monetization_subscription_statuses;
  bonus_used integer;
  allowance_used integer;
begin
  if current_user_id is null then
    raise exception 'auth required';
  end if;
  if credit_amount is null or credit_amount <= 0 or credit_amount > 1000 then
    raise exception 'credit amount must be between 1 and 1000';
  end if;
  if reason is null or btrim(reason) = '' or char_length(reason) > 160 then
    raise exception 'reason must be between 1 and 160 characters';
  end if;
  if metadata is null or jsonb_typeof(metadata) <> 'object' or
      pg_column_size(metadata) > 8192 then
    raise exception 'metadata must be an object no larger than 8192 bytes';
  end if;

  insert into public.monetization_wallets (
    user_id, balance, allowance_remaining, bonus_balance, period_credits,
    lifetime_earned, lifetime_spent, tier, period_ends_at, updated_at
  )
  values (
    current_user_id, 20, 20, 0, 20, 20, 0, 'free', now() + interval '1 day', now()
  )
  on conflict (user_id) do nothing;

  select * into wallet_row
  from public.monetization_wallets
  where user_id = current_user_id
  for update;

  if wallet_row.period_ends_at is not null and wallet_row.period_ends_at <= now() then
    select * into active_status
    from public.monetization_subscription_statuses
    where user_id = current_user_id
      and is_active = true
      and (expires_at is null or expires_at > now())
    order by updated_at desc
    limit 1;

    update public.monetization_wallets
    set tier = case active_status.plan_id
          when 'premium_monthly' then 'premium_monthly'
          when 'premium_yearly' then 'premium_yearly'
          when 'lifetime' then 'lifetime'
          else 'free'
        end,
        period_credits = case active_status.plan_id
          when 'premium_monthly' then 250
          when 'premium_yearly' then 4000
          when 'lifetime' then 0
          else 20
        end,
        allowance_remaining = case active_status.plan_id
          when 'premium_monthly' then 250
          when 'premium_yearly' then 4000
          when 'lifetime' then 0
          else 20
        end,
        balance = bonus_balance + case active_status.plan_id
          when 'premium_monthly' then 250
          when 'premium_yearly' then 4000
          when 'lifetime' then 0
          else 20
        end,
        period_ends_at = case active_status.plan_id
          when 'premium_monthly' then coalesce(active_status.expires_at, now() + interval '30 days')
          when 'premium_yearly' then coalesce(active_status.expires_at, now() + interval '365 days')
          when 'lifetime' then null
          else now() + interval '1 day'
        end,
        updated_at = now()
    where user_id = current_user_id
    returning * into wallet_row;
  end if;

  if wallet_row.balance < credit_amount then
    raise exception 'insufficient credits';
  end if;

  bonus_used := least(wallet_row.bonus_balance, credit_amount);
  allowance_used := credit_amount - bonus_used;

  update public.monetization_wallets
  set bonus_balance = bonus_balance - bonus_used,
      allowance_remaining = greatest(allowance_remaining - allowance_used, 0),
      balance = balance - credit_amount,
      lifetime_spent = lifetime_spent + credit_amount,
      updated_at = now()
  where user_id = current_user_id
  returning * into wallet_row;

  insert into public.monetization_credit_transactions (
    user_id, type, amount, balance_after, source, description, metadata
  )
  values (
    current_user_id, 'spend', -credit_amount, wallet_row.balance,
    'app', reason, metadata
  );

  return query
  select true, wallet_row.balance, wallet_row.allowance_remaining,
         wallet_row.bonus_balance, wallet_row.period_credits,
         wallet_row.lifetime_earned, wallet_row.lifetime_spent,
         wallet_row.tier, wallet_row.updated_at, wallet_row.period_ends_at;
end;
$$;
revoke all on function public.ensure_monetization_wallet(uuid) from public, anon, authenticated;
revoke all on function public.reset_monetization_allowance(uuid) from public, anon, authenticated;
revoke all on function public.grant_monetization_credits(uuid, integer, text, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.consume_monetization_credits(integer, text, jsonb) from public, anon;
grant execute on function public.ensure_monetization_wallet(uuid) to service_role;
grant execute on function public.reset_monetization_allowance(uuid) to service_role;
grant execute on function public.grant_monetization_credits(uuid, integer, text, text, text, jsonb) to service_role;
grant execute on function public.consume_monetization_credits(integer, text, jsonb) to authenticated;
