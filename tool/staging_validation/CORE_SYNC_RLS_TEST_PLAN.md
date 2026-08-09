# Core-Sync RLS Test Plan

**Plan only. Do not execute until RLS mutation-test approval is granted.**

## Scope

Ready tables: `tasks`, `goals`, `habits`, `settings`, `purchase_bindings`, and `user_daily_metrics`.

For each table, use isolated User A and User B rows, then verify:

1. User A can create and read its own row.
2. User B cannot read User A's row.
3. User B cannot update User A's row.
4. User B cannot delete User A's row.
5. User A cannot create or update a row with `user_id = User B UUID`.
6. User B cannot create or update a row with `user_id = User A UUID`.

## Table Mapping

| Table | Ownership column | Local required fields known? | Insert-payload status |
| --- | --- | --- | --- |
| `tasks` | `user_id` | Yes: `id`, `title`; remaining fields have defaults or are nullable. | `NEEDS_INSERT_PAYLOAD_MAPPING` |
| `goals` | `user_id` | Yes: `id`, `title`; remaining fields have defaults or are nullable. | `NEEDS_INSERT_PAYLOAD_MAPPING` |
| `habits` | `user_id` | Yes: `id`, `title`; remaining fields have defaults or are nullable. | `NEEDS_INSERT_PAYLOAD_MAPPING` |
| `settings` | `user_id` | Yes: `id` must be `default`; remaining fields have defaults. | `NEEDS_INSERT_PAYLOAD_MAPPING` |
| `purchase_bindings` | `user_id` | Yes: `token_hash`, `product_id`. | `NEEDS_INSERT_PAYLOAD_MAPPING` |
| `user_daily_metrics` | `user_id` | Yes: `device_id`, `date`; metric fields have defaults. | `NEEDS_INSERT_PAYLOAD_MAPPING` |

No executable payloads are included. Before execution, confirm actual deployed columns, defaults, and conflict keys against migrations and post-migration catalog output.

## Guardrails

- Use only staging User A and User B sessions.
- Use no service-role key.
- Do not test `ai_proxy_rate_limits` as a direct table; it is RPC-only.
- Do not run this plan until separate execution approval exists.
