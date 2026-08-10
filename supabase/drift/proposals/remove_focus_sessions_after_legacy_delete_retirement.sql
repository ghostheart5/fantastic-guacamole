-- REVIEW-ONLY DESTRUCTIVE PROPOSAL. This file is deliberately outside
-- supabase/migrations and must not be executed yet.
--
-- Read-only evidence captured 2026-08-09:
--   * public.focus_sessions exists with RLS enabled and zero rows.
--   * its FKs point to auth.users, public.tasks, and public.goals.
--   * no live Flutter Supabase query for this table was found.
--   * active Edge Function delete-account v4 still deletes this table by name.
--
-- Required approval gates before moving this into migrations:
--   1. retire or update the deployed legacy delete-account function;
--   2. re-check the row count and database dependencies in staging;
--   3. run account deletion for each auth provider after removal;
--   4. take a recoverable database backup and obtain destructive-change review.

begin;

do $$
declare
  focus_row_count bigint;
begin
  if to_regclass('public.focus_sessions') is null then
    return;
  end if;

  execute 'select count(*) from public.focus_sessions' into focus_row_count;
  if focus_row_count <> 0 then
    raise exception
      'focus_sessions contains % rows; archive/review them before removal',
      focus_row_count;
  end if;
end;
$$;

-- Deliberately omit CASCADE. Any remaining database dependency must stop the
-- migration and receive its own review.
drop table if exists public.focus_sessions;

commit;
