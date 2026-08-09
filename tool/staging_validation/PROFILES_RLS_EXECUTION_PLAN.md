# Profiles RLS Execution Plan

**Staging-only executable test design. Do not run until explicit RLS mutation-test approval is granted.**

## Ownership Mapping

`public.profiles` uses `id = auth.uid()`. It does not use `user_id`.

- User A ID: `a6dc2118-2140-4416-8642-9c3eba691288`
- User B ID: `aa116396-4dc1-461e-8502-61b6896570b4`
- Primary key and ownership column: `id`.

## Test Cases

1. User A reads the profile where `id = User A UUID`.
2. User B cannot read the profile where `id = User A UUID`.
3. User B cannot update the profile where `id = User A UUID`.
4. User A cannot insert or update a profile with `id = User B UUID`.
5. User B cannot insert or update a profile with `id = User A UUID`.

## Preconditions and Expected Results

- Profile repair already succeeded for both users; use those existing caller-owned profiles for reads and cross-user denial.
- For attempted cross-user writes, expect an authorization error or zero affected rows; no User A or User B profile may be changed by the other user.
- Do not use `user_id` in payloads, filters, or assertions.
- Do not execute direct profile writes without separate test-row and cleanup approval.
