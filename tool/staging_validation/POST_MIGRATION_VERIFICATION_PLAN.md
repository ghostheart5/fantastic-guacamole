# Post-Migration Verification Plan

**Run this plan only after migrations are explicitly approved and applied to confirmed staging.**

1. Run `npx supabase migration list`.
2. Confirm the Remote column contains the applied migrations.
3. Run [schema_discovery.sql](schema_discovery.sql).
4. Confirm expected tables exist.
5. Run [function_discovery.sql](function_discovery.sql).
6. Confirm expected functions exist.
7. Confirm RLS is enabled and policies are present.
8. Run the ready backend checks.
9. Then generate and execute core-sync RLS tests.
10. Then run receipt-mismatch, Storage, and valid-debit tests.

Do not use service-role keys in client validation, and do not treat any result as production-release approval.
