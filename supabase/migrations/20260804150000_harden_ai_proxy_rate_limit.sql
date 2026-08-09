create table if not exists public.ai_proxy_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count >= 0),
  updated_at timestamptz not null default now()
);

alter table public.ai_proxy_rate_limits enable row level security;
revoke all on public.ai_proxy_rate_limits from anon, authenticated;

create or replace function public.consume_ai_proxy_rate_limit()
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_user_id uuid := auth.uid();
  current_count integer;
begin
  if current_user_id is null then
    raise exception 'auth required';
  end if;

  insert into public.ai_proxy_rate_limits (
    user_id, window_started_at, request_count, updated_at
  )
  values (current_user_id, now(), 1, now())
  on conflict (user_id) do update
  set window_started_at = case
        when public.ai_proxy_rate_limits.window_started_at <= now() - interval '1 minute' then now()
        else public.ai_proxy_rate_limits.window_started_at
      end,
      request_count = case
        when public.ai_proxy_rate_limits.window_started_at <= now() - interval '1 minute' then 1
        else public.ai_proxy_rate_limits.request_count + 1
      end,
      updated_at = now()
  returning request_count into current_count;

  if current_count > 20 then
    raise exception 'rate limit exceeded';
  end if;
  return true;
end;
$$;

revoke all on function public.consume_ai_proxy_rate_limit() from public, anon;
grant execute on function public.consume_ai_proxy_rate_limit() to authenticated;