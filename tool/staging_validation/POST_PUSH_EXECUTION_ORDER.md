# Post-Push Execution Order

**Execute this sequence only after a separately approved, staging-only `db push`. This document does not authorize any command.**

1. Run `npx supabase migration list`.
2. Verify the Remote migration state is populated for expected migrations.
3. Run [schema_discovery.sql](schema_discovery.sql).
4. Verify expected ChronoSpark tables exist.
5. Run [function_discovery.sql](function_discovery.sql).
6. Verify expected ChronoSpark functions exist.
7. Verify RLS is enabled where expected.
8. Verify policies and execute grants match the reviewed migration contract.
9. Run the ready backend checks.
10. Generate core-sync RLS tests.
11. Generate spoofed-upsert tests.
12. Generate receipt-mismatch tests.
13. Generate Storage tests if applicable.

Do not approve production or remove safety gates based on this sequence. Run mutation-capable tests only after the preceding post-migration discovery and approval conditions are satisfied.
