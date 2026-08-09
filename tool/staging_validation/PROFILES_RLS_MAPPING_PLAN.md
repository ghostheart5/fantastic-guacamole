# Profiles RLS Mapping Plan

**Plan only. Do not execute until RLS mutation-test approval is granted.**

## Ownership Mapping

`public.profiles` is owned by `id`, not `user_id`. Local policies use `id = auth.uid()` for SELECT, INSERT, and UPDATE.

## Planned Checks

1. User A can read its own profile where `id = User A UUID`.
2. User B cannot read User A's profile.
3. User B cannot update User A's profile.
4. User A cannot insert or update a profile with `id = User B UUID`.
5. User B cannot insert or update a profile with `id = User A UUID`.

## Preconditions

- Confirm User A and User B profiles exist from the successful profile-repair checks.
- Use the custom ownership mapping `id`, never an invented `user_id` column.
- Do not execute direct profile writes until separate RLS mutation-test approval exists.
