# Core-Sync RLS Execution Plan

**Staging-only executable test design. Do not run until explicit RLS mutation-test approval is granted.**

## Test Identities

- User A: `a6dc2118-2140-4416-8642-9c3eba691288`
- User B: `aa116396-4dc1-461e-8502-61b6896570b4`
- Ownership column: `user_id` for every table in this plan.

## Common Test Cases

For each table below, use a unique test key for User A's row and execute these cases with normal authenticated User A/User B sessions only:

1. User A inserts an own row with `user_id = User A UUID`.
2. User A reads the own row by its complete primary key.
3. User B cannot read User A's row by the same primary key.
4. User B cannot update User A's row by the same primary key.
5. User B cannot delete User A's row by the same primary key.
6. User A cannot insert or update a row with `user_id = User B UUID`.
7. User B cannot insert or update a row with `user_id = User A UUID`.

A denial may be an authorization error or a successful request returning zero affected/visible rows, depending on the PostgREST operation. The expected result must record no cross-user row exposure or mutation.

## Table Execution Readiness

| Table | Primary key / row locator | Status | Notes |
| --- | --- | --- | --- |
| `tasks` | `(user_id, id)` | `READY_TO_IMPLEMENT` | Required fields and defaults are mapped. |
| `goals` | `(user_id, id)` | `READY_TO_IMPLEMENT` | Required fields and defaults are mapped. |
| `habits` | `(user_id, id)` | `READY_TO_IMPLEMENT` | Required fields and defaults are mapped. |
| `settings` | `(user_id, id)` | `READY_TO_IMPLEMENT` | `id` is always `default`; execute sequentially or clean up between users. |
| `purchase_bindings` | `token_hash` | `READY_TO_IMPLEMENT` | Use a unique non-production token hash per run. |
| `user_daily_metrics` | `(user_id, date)` | `READY_TO_IMPLEMENT` | Final migration changes the primary key to `(user_id, date)`. |

## Execution Guardrails

- No service-role or secret key.
- No production URL or credentials.
- No direct tests against `ai_proxy_rate_limits`; it is RPC-only.
- Do not run until separate approval covers test-row setup and cleanup.
- Record each test's exact request identity, row locator, response status, and resulting visible row count.
