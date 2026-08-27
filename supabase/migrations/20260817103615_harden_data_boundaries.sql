-- Harden existing ChronoSpark database boundaries without deleting user data.

-- The quickstart table is not part of the production product. Keep any rows
-- intact, but remove the anonymous/authenticated demo access that exposed the
-- table through the Data API.
drop policy if exists "todos_select_public" on public.todos;
revoke all on table public.todos from anon, authenticated;

-- Purchase-token bindings are written only by the receipt-verification Edge
-- Function with the service role. Direct client access is unnecessary.
revoke all on table public.purchase_bindings from anon, authenticated;

-- Foreign-key and tenant-policy indexes keep ownership checks and auth-user
-- cascade deletion efficient as these tables grow.
create index if not exists purchase_bindings_user_id_idx
  on public.purchase_bindings (user_id);
create index if not exists user_daily_metrics_user_id_idx
  on public.user_daily_metrics (user_id);

-- Cache auth.uid() once per statement and keep every client-visible policy
-- explicitly tenant-scoped.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles for select to authenticated
using ((select auth.uid()) = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "user_daily_metrics_select_authenticated"
  on public.user_daily_metrics;
drop policy if exists "user_daily_metrics_select_own"
  on public.user_daily_metrics;
create policy "user_daily_metrics_select_own"
on public.user_daily_metrics for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "user_daily_metrics_insert_own"
  on public.user_daily_metrics;
create policy "user_daily_metrics_insert_own"
on public.user_daily_metrics for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "user_daily_metrics_update_own"
  on public.user_daily_metrics;
create policy "user_daily_metrics_update_own"
on public.user_daily_metrics for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "chronospark_sync_select_own" on storage.objects;
create policy "chronospark_sync_select_own"
on storage.objects for select to authenticated
using (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = (select auth.uid())::text
);

drop policy if exists "chronospark_sync_insert_own" on storage.objects;
create policy "chronospark_sync_insert_own"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = (select auth.uid())::text
);

drop policy if exists "chronospark_sync_update_own" on storage.objects;
create policy "chronospark_sync_update_own"
on storage.objects for update to authenticated
using (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = (select auth.uid())::text
)
with check (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = (select auth.uid())::text
);

drop policy if exists "chronospark_sync_delete_own" on storage.objects;
create policy "chronospark_sync_delete_own"
on storage.objects for delete to authenticated
using (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = (select auth.uid())::text
);

-- Trigger functions do not need to be callable through the public API. Lock
-- their lookup paths and remove default execute privileges while preserving
-- their existing trigger behavior.
alter function public.handle_new_user() set search_path = '';
alter function public.set_profiles_updated_at() set search_path = '';
alter function public.set_user_daily_metrics_updated_at() set search_path = '';

revoke execute on function public.handle_new_user()
  from public, anon, authenticated;
revoke execute on function public.set_profiles_updated_at()
  from public, anon, authenticated;
revoke execute on function public.set_user_daily_metrics_updated_at()
  from public, anon, authenticated;
