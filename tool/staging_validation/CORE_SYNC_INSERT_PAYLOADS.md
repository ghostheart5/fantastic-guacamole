# Core-Sync Insert Payload Mapping

**Staging-only payload documentation. Do not execute or seed data without explicit approval.**

`<USER_UUID>` and `<UNIQUE_ID>` are placeholders. Never substitute production identities.

## `tasks`

- Ownership column: `user_id`.
- Primary key: `(user_id, id)`.
- Required columns: `user_id`, `id`, `title`.
- Nullable columns: `description`, `kind`, `scheduled_for`, `goal_id`, `completed_at`, `due_date`, `estimated_duration_ms`, `deleted_at`.
- Defaults: `priority`, `difficulty`, `energy_required`, `subtasks`, `recurrence_rule`, `is_completed`, `is_canceled`, `created_at`, `updated_at`.
- Minimal valid payload:

```json
{"user_id":"<USER_UUID>","id":"<UNIQUE_ID>","title":"RLS test task"}
```

## `goals`

- Ownership column: `user_id`.
- Primary key: `(user_id, id)`.
- Required columns: `user_id`, `id`, `title`.
- Nullable columns: `description`, `target_date`, `completed_at`, `archived_at`, `deleted_at`.
- Defaults: `color_hex`, `status`, `created_at`, `updated_at`.
- Minimal valid payload:

```json
{"user_id":"<USER_UUID>","id":"<UNIQUE_ID>","title":"RLS test goal"}
```

## `habits`

- Ownership column: `user_id`.
- Primary key: `(user_id, id)`.
- Required columns: `user_id`, `id`, `title`.
- Nullable columns: `description`, `deleted_at`.
- Defaults: `cadence`, `target_count`, `status`, `active`, `created_at`, `updated_at`.
- Minimal valid payload:

```json
{"user_id":"<USER_UUID>","id":"<UNIQUE_ID>","title":"RLS test habit"}
```

## `settings`

- Ownership column: `user_id`.
- Primary key: `(user_id, id)`.
- Required columns: `user_id`, `id`.
- Nullable columns: `deleted_at`.
- Defaults: `sound_enabled`, `notifications_enabled`, `theme_mode`, `onboarding_complete`, `created_at`, `updated_at`.
- Constraint: `id` must equal `default`.
- Minimal valid payload:

```json
{"user_id":"<USER_UUID>","id":"default"}
```

## `purchase_bindings`

- Ownership column: `user_id`.
- Primary key: `token_hash`.
- Required columns: `token_hash`, `user_id`, `product_id`.
- Nullable columns: none.
- Defaults: `created_at`.
- Minimal valid payload:

```json
{"token_hash":"<UNIQUE_ID>","user_id":"<USER_UUID>","product_id":"rls-test-product"}
```

## `user_daily_metrics`

- Ownership column: `user_id`.
- Final primary key: `(user_id, date)`.
- Required columns: `device_id`, `date`, `user_id`.
- Nullable columns: none.
- Defaults: `tasks_created`, `tasks_completed`, `momentum_peak`, `created_at`, `updated_at`.
- Minimal valid payload:

```json
{"device_id":"<UNIQUE_ID>","date":"<ISO_DATE>","user_id":"<USER_UUID>"}
```

## Payload Safety

Before any execution, confirm the deployed columns and constraints still match the final migration chain. These are documentation templates, not approved seed data.
