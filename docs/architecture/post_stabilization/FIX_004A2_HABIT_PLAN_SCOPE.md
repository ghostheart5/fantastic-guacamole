# FIX-004A2 — Habit / Plan V2 account-scoped persistence

Habits previously stored their `habit_records_v1` aggregate in global
`habits_box`; Plans stored date-keyed JSON in global `daily_plans_box`. Both
now use separate encrypted V2 Hive boxes constructed from
`accountStorageScopeProvider`. Unsafe transitions receive unavailable
repositories, never a global or signed-out fallback.

Habit legacy ownership is **AMBIGUOUS** despite optional `userId`: the global
aggregate can contain missing/mixed entries and has no authoritative manifest.
Plan legacy ownership is **AMBIGUOUS**: records contain no user identity.
Neither legacy source is migrated, claimed, hydrated, overwritten, or deleted.

Root-05 already drains Habits. This repair adds Plan drain and invalidates its
repository, domain repository, and use cases on identity change. Habit reminder
input is therefore loaded from the current V2 box after recreation; scheduled
device-reminder ownership remains a later repair.

The lifecycle hunk is a required Plan handoff dependency: Plan/domain providers
cache repositories using `ref.read`, so scope watching alone cannot guarantee an
A-scoped instance is discarded before B becomes ready. It changes no lifecycle
ordering or behavior outside Plan drain and Plan dependency invalidation.

Selected groups: scoped encrypted box construction; Habit/Plan unavailable
repositories; Plan drain/invalidation; scoped account-deletion cleanup. No
Creator recurring-task behavior, reminder scheduling semantics, Plan product
flow, AI/SI logic, or domain schema changed.
