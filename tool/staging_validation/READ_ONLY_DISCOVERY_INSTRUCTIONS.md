# Read-Only Staging Discovery Instructions

1. Open Supabase Dashboard.
2. Select project: `RETIRED_STAGING_PROJECT`.
3. Open SQL Editor.
4. Run [schema_discovery.sql](schema_discovery.sql).
5. Save, export, or copy the result.
6. Run [function_discovery.sql](function_discovery.sql).
7. Save, export, or copy the result.
8. Do not run any SQL that inserts, updates, deletes, drops, truncates, creates, alters, grants, revokes, or applies migrations.

## Warning

If both discovery files return no expected tables or functions, staging is likely empty and migrations need a separate reviewed application plan.
