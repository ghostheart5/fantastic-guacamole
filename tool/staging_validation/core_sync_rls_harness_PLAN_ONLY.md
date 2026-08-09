# Core-Sync RLS Harness Plan Only

Status: **`TABLE_MISSING_OR_WRONG_SCHEMA`**. The prior preflight returned `exists=false` for every table below in `public`. This document is not executable and contains no insert, select, update, or delete test SQL.

| Table | Test permitted only when all conditions are confirmed | Current status |
| --- | --- | --- |
| `profiles` | table exists; ownership column is `user_id`; `user_id` type is `uuid`; RLS enabled; policies use `auth.uid()`; required insert payload columns known | `NEEDS_SCHEMA_CONFIRMATION` |
| `tasks` | table exists; ownership column is `user_id`; `user_id` type is `uuid`; RLS enabled; policies use `auth.uid()`; required insert payload columns known | `NEEDS_SCHEMA_CONFIRMATION` |
| `goals` | table exists; ownership column is `user_id`; `user_id` type is `uuid`; RLS enabled; policies use `auth.uid()`; required insert payload columns known | `NEEDS_SCHEMA_CONFIRMATION` |
| `habits` | table exists; ownership column is `user_id`; `user_id` type is `uuid`; RLS enabled; policies use `auth.uid()`; required insert payload columns known | `NEEDS_SCHEMA_CONFIRMATION` |
| `settings` | table exists; ownership column is `user_id`; `user_id` type is `uuid`; RLS enabled; policies use `auth.uid()`; required insert payload columns known | `NEEDS_SCHEMA_CONFIRMATION` |
| `purchase_bindings` | table exists; ownership column is `user_id`; `user_id` type is `uuid`; RLS enabled; policies use `auth.uid()`; required insert payload columns known | `NEEDS_SCHEMA_CONFIRMATION` |
| `user_daily_metrics` | table exists; ownership column is `user_id`; `user_id` type is `uuid`; RLS enabled; policies use `auth.uid()`; required insert payload columns known | `NEEDS_SCHEMA_CONFIRMATION` |

Before generating a live RLS harness, obtain read-only migration history plus [schema discovery](schema_discovery.sql) output that locates each table. If any condition remains unmet, retain `NEEDS_SCHEMA_CONFIRMATION` and do not generate mutation tests.