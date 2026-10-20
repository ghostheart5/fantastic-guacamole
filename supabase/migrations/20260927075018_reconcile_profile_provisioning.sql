-- Restore the reviewed profile contract after hosted schema/trigger drift.
-- Optional signup metadata must not prevent a profile from being created.
alter table public.profiles
  alter column email drop not null,
  alter column email drop default,
  alter column full_name drop not null,
  alter column full_name drop default,
  alter column avatar_url drop not null,
  alter column avatar_url drop default;

-- The hardened source function validates trigger context and does not suppress
-- provisioning failures. The live trigger had retained an older private copy.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Repair only missing profiles. Preserve all existing profile values and do
-- not recreate data for an account with an active deletion request.
insert into public.profiles (id, email, full_name, avatar_url)
select u.id, u.email,
  coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name'),
  u.raw_user_meta_data ->> 'avatar_url'
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
  and not exists (
    select 1 from public.account_deletion_requests d where d.user_id = u.id
  )
on conflict (id) do nothing;
