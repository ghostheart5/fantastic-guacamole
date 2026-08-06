-- SECURITY FIX: Harden RLS policies on user_daily_metrics.
--
-- Previously the SELECT policy used USING (true), which allowed any
-- authenticated user to read every row in the table — a cross-tenant
-- data exposure. Every sibling policy in this schema (profiles, purchase_bindings,
-- storage objects) correctly scopes reads to auth.uid() = user_id. This
-- migration brings user_daily_metrics into line with that invariant.
--
-- The UPDATE policy is also hardened: the "user_id is null or …" branch
-- was originally written to handle rows that pre-dated the user_id column.
-- user_id is now NOT NULL with a default, so the null-bypass path is dead
-- code and a security risk; it is removed here.
--
-- No user data is deleted or modified. This is a policy-only change.

-- DROP the broad SELECT policy that allowed cross-tenant reads.
drop policy if exists "user_daily_metrics_select_authenticated" on public.user_daily_metrics;

-- REPLACE with a user-scoped policy matching the same pattern as
-- profiles_select_own and purchase_bindings_select_own.
create policy "user_daily_metrics_select_own"
on public.user_daily_metrics
for select
to authenticated
using (auth.uid() = user_id);

-- Harden the UPDATE policy: remove the dead "user_id is null" bypass branch.
-- Before this fix, any authenticated user could claim an orphaned row
-- (user_id IS NULL) and stamp their own user_id onto it. Combined with the
-- old SELECT policy, an attacker could enumerate device_ids and then claim
-- rows via the null-bypass. This closes both ends of that path.
drop policy if exists "user_daily_metrics_update_own" on public.user_daily_metrics;

create policy "user_daily_metrics_update_own"
on public.user_daily_metrics
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Verification queries (run manually against staging before production):
--
-- 1. As user A (authenticated): should return only A's rows
--    select * from public.user_daily_metrics;
--
-- 2. As user B (authenticated): result set must NOT overlap with user A's rows
--    select * from public.user_daily_metrics;
--
-- 3. As anon: should return 0 rows (anon is revoked via the grant in 202607110002)
--    select * from public.user_daily_metrics;
--
-- 4. Confirm policy names in pg_policies:
--    select policyname, cmd, qual
--    from pg_policies
--    where tablename = 'user_daily_metrics'
--    order by policyname;
--    Expected: user_daily_metrics_select_own (qual: (auth.uid() = user_id))
--              user_daily_metrics_insert_own
--              user_daily_metrics_update_own (qual: (auth.uid() = user_id))
