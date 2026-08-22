# Supabase hosted-state drift inventory

This directory contains review evidence, not deployable Edge Functions. The
snapshots preserve the exact source returned by the read-only Supabase MCP for
active functions that had no repository source on 2026-08-09. Do not move them
into `supabase/functions/` or deploy them without a separate security review.

The legacy snapshots have known reasons not to promote them:

- `verify-receipt` is an older billing implementation that diverges from the
  current `monetization-verify` path.
- `delete-account` has wildcard CORS, a manually maintained deletion list, and
  references the removed `focus_sessions` table.
- `webhook-ingest` is only an authenticated echo/smoke endpoint.

Fail-closed 410 tombstones now exist at the corresponding local function paths.
Deploy those reviewed tombstones to staging and production before treating the
legacy functions as retired; the snapshots in this directory remain historical
evidence of the hosted versions captured on 2026-08-09.

## Verify the checked-in capture

Run:

```powershell
deno test --allow-read supabase/drift/verify_manifest_test.ts
```

This checks migration filenames, immutable snapshot hashes, the format of
historical hashes for mutable repository sources, Edge Function JWT flags, and
the manifest's table inventory. It does not contact production or pretend that
today's repository source is identical to the source captured on 2026-08-09.

The captured zero-byte
`20260809164233_optimize_legacy_auth_uid_policies.sql` artifact is recorded as
excluded evidence, not kept in `supabase/migrations/`, because an empty SQL file
is not a deployable migration.

## Refresh procedure

Refresh only through read-only inventory calls:

1. `list_migrations`
2. `list_edge_functions`, followed by `get_edge_function` for every active slug
3. `list_tables` for `public`, including verbose FK evidence where relevant
4. security and performance `get_advisors`

Record the capture date and preserve each deployed bundle hash separately from
the SHA-256 of its returned source. Never use `apply_migration`, deploy a
function, delete an object, or change Auth/Storage configuration merely to
refresh this inventory.

## Open production gates

- The migration `20260809170000_harden_function_privileges_and_data_api_defaults.sql`
  is local-only until it is reviewed, replayed on a clean local stack, tested in
  staging, and the hosted advisors are re-run.
- The project-pinned Supabase CLI is available, but Docker and a staging project
  are not configured on this workstation. The GitHub
  `supabase-database.yml` gate now requires a clean migration replay, pgTAP,
  and SQL lint before an Android release can build.
- The 24 hosted-only tables were recovered from a read-only PostgreSQL catalog
  capture in `20260809221655_recover_hosted_public_tables.sql`. An isolated
  PostgreSQL 17 replay passed locally. The clean Supabase stack additionally
  requires recovered task and goal links to use the canonical account-scoped
  `(user_id, id)` keys; the Supabase-specific clean-stack CI and staging replay
  remain mandatory before production deployment.
- A read-only foreign-key audit found eleven account-owned tables with no
  `auth.users` foreign key and `app_events` using `ON DELETE SET NULL`. All
  twelve tables were empty at capture time. The fail-closed follow-up migration
  `20260809221704_enforce_recovered_account_deletion_cascades.sql` also requires
  leading user indexes. Its pgTAP contract must pass in staging before account
  deletion can be approved for production.
- Leaked-password protection is a Dashboard/Auth configuration gate and is not
  changed by a SQL migration.
- The four authenticated SECURITY DEFINER warnings documented in the manifest
  are intentional with the current caller architecture. They still require
  behavioral negative tests and periodic review.
- `focus_sessions` cannot be dropped while the active legacy `delete-account`
  source still treats that table as mandatory. The reviewed proposal is kept
  outside `supabase/migrations/` so it cannot run accidentally.
