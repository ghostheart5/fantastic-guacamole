# Staging Migration Safety Review

**Review only. No migration commands were run.**

## Scope and Conclusion

All 12 files under `supabase/migrations/` were inspected locally. One migration contains data-destructive operations: `20260717170000_secure_user_daily_metrics.sql` deletes orphaned metric rows and truncates `public.user_daily_metrics` as part of a table-key rebuild. It is safe only when staging is confirmed empty/disposable and the preceding migrations are applied in order; it is a blocker for a populated or manually modified target until separately reviewed.

`DROP POLICY`, `DROP TRIGGER`, `DROP FUNCTION`, and `CREATE OR REPLACE FUNCTION` statements replace schema objects rather than table data, but require review for compatibility with manually created staging objects.

| Migration | Creates tables/functions/policies | Enables RLS | Grants/revokes | Contains `DROP` | `TRUNCATE` | `DELETE` without `WHERE` | Destructive `ALTER COLUMN` | `CREATE OR REPLACE FUNCTION` | `SECURITY DEFINER` | Reset-like behavior | Safe for empty staging? | Needs manual review? |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `202607050001_purchase_bindings.sql` | Table, policies | Yes | Yes | Policies | No | No | No | No | No | No | Yes | Yes - policy replacement and table privileges |
| `202607110001_profiles.sql` | Table, trigger functions, trigger, policies | Yes | Yes | Trigger, policies | No | No | No | Yes | Yes | No | Yes | Yes - auth trigger and privileged function |
| `202607110002_data_policies.sql` | Metrics table, function, trigger, Storage bucket/policies | Yes | Yes | Trigger, policies | No | No | No - only default change | Yes | No | No | Yes | Yes - existing-row update, Storage contract, later policy replacement |
| `20260711160649_new-migration.sql` | None; empty file | No | No | No | No | No | No | No | No | No | Yes | No |
| `20260712143000_resilient_handle_new_user.sql` | Function | No | No | No | No | No | No | Yes | Yes | No | Yes | Yes - exception handling changes provisioning behavior |
| `20260716193000_monetization_system.sql` | Monetization tables, indexes, policies, RPCs | Yes | Yes | Policies | No | No | No | Yes | No | No | Yes | Yes - privileged execute grants and purchase semantics |
| `20260717170000_secure_user_daily_metrics.sql` | Temp table, index, policies, function | No | Yes | Temp table, constraint, policies, function | **Yes** | No - deletes only `WHERE user_id is null` | **Yes** - sets `user_id` not null and replaces primary key | Yes | Yes | **Yes** - data rebuild | **Yes, only with the full ordered chain on confirmed empty/disposable staging** | **Yes - destructive for populated data; blocker otherwise** |
| `20260802120000_harden_security_definer_functions.sql` | Functions | No | Yes | No | No | No | No | Yes | Yes | No | Yes | Yes - dynamic grants and SECURITY DEFINER exposure |
| `20260804120000_harden_monetization_credit_rpc.sql` | Functions | No | Yes | No | No | No | No | Yes | Yes - credit consumption RPC | No | Yes | Yes - privileged mutation semantics and grants |
| `20260804130000_create_core_sync_tables_with_rls.sql` | Core-sync tables, indexes, policies | Yes | Yes | No | No | No | No | No | No | No | Yes | Yes - conflicts with manually created tables/policies must be ruled out |
| `20260804140000_harden_metrics_and_profile_provisioning.sql` | Functions | No | Yes | No | No | No | No | Yes | Yes | No | Yes | Yes - depends on profiles and metrics tables; changes RPC exposure |
| `20260804150000_harden_ai_proxy_rate_limit.sql` | Table, function | Yes | Yes | No | No | No | No | Yes | Yes | No | Yes | Yes - auth-dependent rate-limit behavior |

## Review Gate

No migration application is approved by this review. Before any future application, confirm staging is the intended disposable target, obtain schema discovery output for manually created objects, and obtain explicit human approval.
