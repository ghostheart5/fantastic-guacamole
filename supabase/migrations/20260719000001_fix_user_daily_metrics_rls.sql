-- Audit v2.0 security fix: user_daily_metrics RLS
--
-- BOLA / IDOR: the original SELECT policy used `using (true)`, which allowed
-- any authenticated user to read every other user's daily metrics.
-- Fix: scope SELECT to own rows only.
--
-- The original UPDATE USING clause permitted rows where user_id IS NULL to be
-- updated by any authenticated user.  Fix: require user_id match.
-- Both USING and WITH CHECK are set to prevent row hijacking on UPDATE.

drop policy if exists "user_daily_metrics_select_authenticated" on public.user_daily_metrics;
create policy "user_daily_metrics_select_own"
on public.user_daily_metrics
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "user_daily_metrics_update_own" on public.user_daily_metrics;
create policy "user_daily_metrics_update_own"
on public.user_daily_metrics
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
