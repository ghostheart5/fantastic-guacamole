-- Retire the pre-quote direct debit API. It has no current Flutter caller and
-- its daily/yearly allowances conflict with the canonical reservation policy.
-- Retain the function for a deliberate compatibility review; no wallet rows or
-- balances are changed. An old client receives permission_denied without debit.
revoke all on function public.consume_monetization_credits(integer, text, jsonb)
  from public, anon, authenticated, service_role;

comment on function public.consume_monetization_credits(integer, text, jsonb) is
  'Retired direct client debit API. No API role may execute. Use server-authorized quote/reserve/settle AI usage.';
