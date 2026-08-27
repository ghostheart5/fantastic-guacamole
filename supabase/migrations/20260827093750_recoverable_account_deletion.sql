create table if not exists public.account_deletion_requests (
  request_id text primary key
    check (request_id ~ '^[0-9a-f]{64}$'),
  user_id uuid unique,
  receipt_hash text
    check (receipt_hash is null or receipt_hash ~ '^[0-9a-f]{64}$'),
  state text not null default 'requested'
    check (state in ('requested', 'sessions_revoked', 'storage_deleted', 'completed')),
  lease_id uuid,
  lease_until timestamptz,
  attempts integer not null default 0 check (attempts >= 0),
  sessions_revoked_at timestamptz,
  storage_deleted_at timestamptz,
  auth_deleted_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint account_deletion_identity_check check (
    user_id is not null and receipt_hash is not null
  )
);

create index if not exists account_deletion_requests_pending_idx
  on public.account_deletion_requests (updated_at)
  where state <> 'completed';

alter table public.account_deletion_requests enable row level security;
revoke all on table public.account_deletion_requests
  from public, anon, authenticated, service_role;
grant select, insert, update on table public.account_deletion_requests
  to service_role;

create or replace function public.claim_account_deletion_request(
  p_request_id text,
  p_receipt_hash text,
  p_user_id uuid,
  p_lease_id uuid,
  p_allow_internal boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests;
begin
  if p_request_id !~ '^[0-9a-f]{64}$'
    or p_lease_id is null
    or (not p_allow_internal and p_receipt_hash !~ '^[0-9a-f]{64}$') then
    raise exception 'invalid account deletion request';
  end if;

  if not p_allow_internal then
    if p_user_id is null then
      raise exception 'authenticated user is required';
    end if;

    select * into v_request
    from public.account_deletion_requests
    where user_id = p_user_id
    for update;

    if found and v_request.request_id <> p_request_id then
      return jsonb_build_object(
        'claimed', false,
        'retry', false,
        'state', v_request.state,
        'reason', 'request_identity_conflict'
      );
    end if;

    if found and v_request.receipt_hash <> p_receipt_hash then
      update public.account_deletion_requests
      set receipt_hash = p_receipt_hash,
          updated_at = now()
      where user_id = p_user_id;
    end if;

    if not found then
      insert into public.account_deletion_requests (
        request_id,
        user_id,
        receipt_hash
      ) values (
        p_request_id,
        p_user_id,
        p_receipt_hash
      )
      on conflict (request_id) do nothing;
    end if;
  end if;

  select * into v_request
  from public.account_deletion_requests
  where request_id = p_request_id
    and (
      p_allow_internal
      or (user_id = p_user_id and receipt_hash = p_receipt_hash)
    )
  for update;

  if not found then
    return jsonb_build_object(
      'claimed', false,
      'retry', false,
      'state', 'not_found'
    );
  end if;

  if v_request.state = 'completed' then
    return jsonb_build_object(
      'claimed', false,
      'completed', true,
      'state', 'completed'
    );
  end if;

  if v_request.lease_until is not null and v_request.lease_until > now() then
    return jsonb_build_object(
      'claimed', false,
      'completed', false,
      'retry', true,
      'state', v_request.state
    );
  end if;

  update public.account_deletion_requests
  set lease_id = p_lease_id,
      lease_until = now() + interval '15 minutes',
      attempts = attempts + 1,
      updated_at = now()
  where request_id = p_request_id;

  return jsonb_build_object(
    'claimed', true,
    'completed', false,
    'state', v_request.state,
    'userId', v_request.user_id,
    'sessionsRevoked', v_request.sessions_revoked_at is not null,
    'storageDeleted', v_request.storage_deleted_at is not null
  );
end;
$$;

revoke all on function public.claim_account_deletion_request(
  text, text, uuid, uuid, boolean
) from public, anon, authenticated, service_role;
grant execute on function public.claim_account_deletion_request(
  text, text, uuid, uuid, boolean
) to service_role;

-- Auth sessions are outside the exposed public schema. This function is
-- intentionally limited to the user attached to a live deletion-request lease.
create or replace function public.revoke_account_deletion_sessions(
  p_request_id text,
  p_lease_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  select user_id into v_user_id
  from public.account_deletion_requests
  where request_id = p_request_id
    and lease_id = p_lease_id
    and lease_until > now()
    and state <> 'completed'
  for update;

  if v_user_id is null then
    return false;
  end if;

  delete from auth.sessions where user_id = v_user_id;
  return true;
end;
$$;

revoke all on function public.revoke_account_deletion_sessions(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.revoke_account_deletion_sessions(text, uuid)
  to service_role;

-- Keep a durable tombstone after completion. Supabase Auth JWTs can remain
-- cryptographically valid after session and user deletion, so storage write
-- policies must also consult server-owned deletion state.
create or replace function public.account_deletion_in_progress()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.account_deletion_requests
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.account_deletion_in_progress()
  from public, anon, authenticated, service_role;
grant execute on function public.account_deletion_in_progress()
  to authenticated;

drop policy if exists "chronospark_sync_insert_own" on storage.objects;
create policy "chronospark_sync_insert_own"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = (select auth.uid())::text
  and not public.account_deletion_in_progress()
);

drop policy if exists "chronospark_sync_update_own" on storage.objects;
create policy "chronospark_sync_update_own"
on storage.objects for update to authenticated
using (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = (select auth.uid())::text
  and not public.account_deletion_in_progress()
)
with check (
  bucket_id = 'chronospark-sync'
  and split_part(name, '/', 1) = (select auth.uid())::text
  and not public.account_deletion_in_progress()
);
