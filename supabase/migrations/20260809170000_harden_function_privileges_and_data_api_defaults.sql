-- Make Data API exposure opt-in and pin the effective privilege contract for
-- the SECURITY DEFINER functions that are present in ChronoSpark migrations.
--
-- Supabase's 2026 secure-by-default rollout separates object GRANTs from RLS.
-- RLS still controls rows, but a table/function is not reachable through the
-- Data API unless the caller also has the corresponding object privilege.

-- New objects created by the postgres migration owner must not become Data API
-- endpoints implicitly. Every future migration must grant only the operations
-- its anon/authenticated/service_role caller actually needs and enable RLS on
-- every granted table in an exposed schema.
alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon, authenticated, service_role;
-- Existing server-side REST access must be explicit so a fresh project created
-- after the secure-by-default rollout behaves like the current project.
revoke all on table public.purchase_bindings from service_role;
grant select, insert on table public.purchase_bindings to service_role;
grant select, insert, update, delete on table
  public.monetization_subscription_statuses,
  public.monetization_wallets,
  public.monetization_credit_transactions,
  public.monetization_purchases,
  public.monetization_entitlement_events
to service_role;
-- Trigger-only profile provisioning. Ordinary Data API roles must never call
-- this SECURITY DEFINER function directly.
alter function public.handle_new_user() set search_path = '';
revoke all on function public.handle_new_user() from public, anon, authenticated;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function public.handle_new_user() to service_role';
  end if;

  if exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    execute 'grant execute on function public.handle_new_user() to supabase_auth_admin';
  end if;
end;
$$;
-- This aggregate has no approved client or Edge Function caller.
alter function public.get_global_metrics() set search_path = '';
revoke all on function public.get_global_metrics()
  from public, anon, authenticated, service_role;
-- These four RPCs are intentionally callable by authenticated users. Each has
-- a fixed interface, requires auth.uid(), and constrains writes to that caller.
-- Keep that required API while removing inherited PUBLIC/anon/service access.
alter function public.ensure_profile_for_current_user() set search_path = '';
revoke all on function public.ensure_profile_for_current_user()
  from public, anon, authenticated, service_role;
grant execute on function public.ensure_profile_for_current_user() to authenticated;
alter function public.consume_monetization_credits(integer, text, jsonb)
  set search_path = '';
revoke all on function public.consume_monetization_credits(integer, text, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.consume_monetization_credits(integer, text, jsonb)
  to authenticated;
alter function public.consume_ai_proxy_rate_limit() set search_path = '';
revoke all on function public.consume_ai_proxy_rate_limit()
  from public, anon, authenticated, service_role;
grant execute on function public.consume_ai_proxy_rate_limit() to authenticated;
alter function public.consume_monetization_verify_rate_limit()
  set search_path = '';
revoke all on function public.consume_monetization_verify_rate_limit()
  from public, anon, authenticated, service_role;
grant execute on function public.consume_monetization_verify_rate_limit()
  to authenticated;
