-- Bound persistent push registrations per account and prevent a caller from
-- taking another installation's token by presenting the token alone. The same
-- installation ID can still move between accounts on a legitimate sign-in.
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
  v_existing boolean;
  v_device_count integer;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication is required.';
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

  -- Lock the same installation and token across accounts before deciding what
  -- may be removed. The separate namespaces and fixed order avoid lock cycles.
  perform pg_catalog.pg_advisory_xact_lock(1, pg_catalog.hashtext(v_installation_id));
  perform pg_catalog.pg_advisory_xact_lock(2, pg_catalog.hashtext(v_token));
  perform pg_catalog.pg_advisory_xact_lock(3, pg_catalog.hashtext(v_user_id::text));

  -- A device that changed accounts must stop receiving the previous account's
  -- notifications even when the new owner has reached the registration cap.
  delete from public.firebase_device_registrations
  where installation_id = v_installation_id and user_id <> v_user_id;

  -- A token alone never proves control of a different installation/account.
  if exists (
    select 1 from public.firebase_device_registrations
    where token = v_token and user_id <> v_user_id
  ) then
    return 0;
  end if;

  select exists (
    select 1 from public.firebase_device_registrations
    where user_id = v_user_id
      and (installation_id = v_installation_id or token = v_token)
  ) into v_existing;
  if not v_existing then
    select count(*) into v_device_count
    from public.firebase_device_registrations where user_id = v_user_id;
    if v_device_count >= 20 then
      return 0;
    end if;
  end if;

  -- A token may displace another installation only within the same account.
  delete from public.firebase_device_registrations
  where user_id = v_user_id and token = v_token
    and installation_id <> v_installation_id;

  insert into public.firebase_device_registrations (
    user_id, installation_id, token, platform, source, last_seen_at
  ) values (
    v_user_id, v_installation_id, v_token, v_platform, v_source,
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

revoke all on function public.register_firebase_device(text, text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.register_firebase_device(text, text, text, text)
  to authenticated;
comment on function public.register_firebase_device(text, text, text, text) is
  'Claims one installation for auth.uid(); rejects cross-owner token-only transfer and returns zero at the 20-device limit.';
