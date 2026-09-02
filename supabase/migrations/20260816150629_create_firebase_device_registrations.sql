-- Server-managed, multi-device Firebase Cloud Messaging registrations.
-- Client callers can only claim or release their current installation through
-- the narrowly granted RPCs below; raw tokens are never exposed through the
-- Data API to anon or authenticated roles.

create table public.firebase_device_registrations (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  installation_id text not null,
  token text not null,
  platform text not null,
  source text not null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint firebase_device_registrations_installation_id_length
    check (char_length(installation_id) between 20 and 128),
  constraint firebase_device_registrations_token_length
    check (char_length(token) between 16 and 4096),
  constraint firebase_device_registrations_platform
    check (platform in ('android', 'ios', 'web', 'macos', 'windows', 'linux')),
  constraint firebase_device_registrations_source_length
    check (char_length(source) between 1 and 64),
  constraint firebase_device_registrations_installation_id_key
    unique (installation_id),
  constraint firebase_device_registrations_token_key unique (token)
);

create index firebase_device_registrations_user_last_seen_idx
  on public.firebase_device_registrations (user_id, last_seen_at desc);

alter table public.firebase_device_registrations enable row level security;

revoke all on table public.firebase_device_registrations
  from public, anon, authenticated, service_role;
revoke all on sequence public.firebase_device_registrations_id_seq
  from public, anon, authenticated, service_role;

grant select, insert, update, delete
  on table public.firebase_device_registrations to service_role;
grant usage, select
  on sequence public.firebase_device_registrations_id_seq to service_role;

create or replace function public.register_firebase_device(
  p_installation_id text,
  p_token text,
  p_platform text,
  p_source text
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_installation_id text := pg_catalog.btrim(p_installation_id);
  v_token text := pg_catalog.btrim(p_token);
  v_platform text := pg_catalog.lower(pg_catalog.btrim(p_platform));
  v_source text := pg_catalog.btrim(p_source);
  v_registration_id bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if pg_catalog.char_length(v_installation_id) not between 20 and 128 then
    raise exception using errcode = '22023', message = 'Invalid installation ID.';
  end if;
  if pg_catalog.char_length(v_token) not between 16 and 4096 then
    raise exception using errcode = '22023', message = 'Invalid messaging token.';
  end if;
  if v_platform not in ('android', 'ios', 'web', 'macos', 'windows', 'linux') then
    raise exception using errcode = '22023', message = 'Invalid device platform.';
  end if;
  if pg_catalog.char_length(v_source) not between 1 and 64 then
    raise exception using errcode = '22023', message = 'Invalid registration source.';
  end if;

  delete from public.firebase_device_registrations
  where (installation_id = v_installation_id or token = v_token)
    and not (user_id = v_user_id and installation_id = v_installation_id);

  insert into public.firebase_device_registrations (
    user_id,
    installation_id,
    token,
    platform,
    source,
    last_seen_at
  )
  values (
    v_user_id,
    v_installation_id,
    v_token,
    v_platform,
    v_source,
    pg_catalog.clock_timestamp()
  )
  on conflict (installation_id) do update set
    user_id = excluded.user_id,
    token = excluded.token,
    platform = excluded.platform,
    source = excluded.source,
    last_seen_at = excluded.last_seen_at
  returning id into v_registration_id;

  return v_registration_id;
end;
$$;

create or replace function public.unregister_firebase_device(
  p_installation_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_installation_id text := pg_catalog.btrim(p_installation_id);
  v_deleted bigint;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;
  if pg_catalog.char_length(v_installation_id) not between 20 and 128 then
    raise exception using errcode = '22023', message = 'Invalid installation ID.';
  end if;

  delete from public.firebase_device_registrations
  where user_id = v_user_id
    and installation_id = v_installation_id;
  get diagnostics v_deleted = row_count;
  return v_deleted = 1;
end;
$$;

revoke all on function public.register_firebase_device(text, text, text, text)
  from public, anon, authenticated, service_role;
revoke all on function public.unregister_firebase_device(text)
  from public, anon, authenticated, service_role;
grant execute on function public.register_firebase_device(text, text, text, text)
  to authenticated;
grant execute on function public.unregister_firebase_device(text)
  to authenticated;

comment on table public.firebase_device_registrations is
  'Service-readable FCM delivery registrations, one current owner per installation and token.';
comment on function public.register_firebase_device(text, text, text, text) is
  'Claims the caller device and messaging token for auth.uid() without exposing the registration table.';
comment on function public.unregister_firebase_device(text) is
  'Releases only the caller-owned device registration.';

notify pgrst, 'reload schema';;
