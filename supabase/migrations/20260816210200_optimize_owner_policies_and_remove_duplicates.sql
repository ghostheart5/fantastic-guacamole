-- Preserve owner-only behavior while allowing Postgres to initialize the
-- authenticated user once per statement instead of once per candidate row.
alter policy milestones_select_own on public.milestones
  using ((select auth.uid()) = user_id);
alter policy milestones_insert_own on public.milestones
  with check ((select auth.uid()) = user_id);
alter policy milestones_update_own on public.milestones
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy milestones_delete_own on public.milestones
  using ((select auth.uid()) = user_id);

alter policy "memoryEngine_select_own" on public."memoryEngine"
  using ((select auth.uid()) = user_id);
alter policy memoryengine_insert_own on public."memoryEngine"
  with check ((select auth.uid()) = user_id);
alter policy memoryengine_update_own on public."memoryEngine"
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy memoryengine_delete_own on public."memoryEngine"
  using ((select auth.uid()) = user_id);

alter policy user_daily_metrics_select_own on public.user_daily_metrics
  using ((select auth.uid()) = user_id);
alter policy user_daily_metrics_update_own on public.user_daily_metrics
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- The canonical policies below are equivalent and already owner-scoped. The
-- older display-name variants only duplicate work for every Habit query.
drop policy if exists "habits - select own" on public.habits;
drop policy if exists "habits - insert own" on public.habits;
drop policy if exists "habits - update own" on public.habits;
drop policy if exists "habits - delete own" on public.habits;

;
