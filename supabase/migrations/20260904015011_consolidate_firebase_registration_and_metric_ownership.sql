-- Consolidate push registration behind the server-owned Firebase RPC and
-- remove a legacy raw-token table that duplicated the same responsibility.
-- The production table was verified empty before this migration. Abort rather
-- than discard data if a stale client writes a row before deployment.
do $$
begin
  if to_regclass('public.user_push_tokens') is not null
     and exists (select 1 from public.user_push_tokens) then
    raise exception
      'user_push_tokens is not empty; migrate registrations before dropping it';
  end if;
end
$$;

drop table if exists public.user_push_tokens;
drop function if exists public.set_user_push_tokens_updated_at();

-- Sign-out releases every Firebase registration owned by the authenticated
-- account without accepting a caller-supplied owner identifier.
revoke all on function public.unregister_firebase_device(text)
  from public, anon, authenticated, service_role;
drop function public.unregister_firebase_device(text);

create function public.unregister_firebase_device()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_deleted integer;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  delete from public.firebase_device_registrations
  where user_id = v_user_id;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.unregister_firebase_device()
  from public, anon, authenticated, service_role;
grant execute on function public.unregister_firebase_device()
  to authenticated;

comment on function public.unregister_firebase_device() is
  'Releases every Firebase registration owned by auth.uid() during an account boundary.';

-- Three legacy rows used a pre-account-scoped device identifier shared by two
-- owners. Preserve the metrics while replacing only cross-owner identifiers
-- with a deterministic per-owner hash. Abort if the audited production target
-- changed before this migration so the broader data set is never rewritten.
do $$
declare
  v_candidate_count integer;
begin
  select count(*)
  into v_candidate_count
  from public.user_daily_metrics metrics
  where metrics.device_id in (
    select device_id
    from public.user_daily_metrics
    group by device_id
    having count(distinct user_id) > 1
  );

  if v_candidate_count not in (0, 3) then
    raise exception
      'Expected 0 rows on a clean replay or 3 audited legacy rows, found %',
      v_candidate_count;
  end if;
end
$$;

with shared_device_ids as (
  select device_id
  from public.user_daily_metrics
  group by device_id
  having count(distinct user_id) > 1
)
update public.user_daily_metrics metrics
set device_id = substring(
  encode(
    extensions.digest(
      convert_to(metrics.device_id || ':' || metrics.user_id::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  )
  from 1 for 32
)
where metrics.device_id in (select device_id from shared_device_ids);

notify pgrst, 'reload schema';
