# GhostHeart5 Supabase drift evidence

GhostHeart5 production (`qpwhuckyirnqtmvhpede`) is the sole current Supabase
authority. The 2026-08-16 manifests at the parent directory preserve its 23
applied migrations and ten deployed Edge Function bundles.

Run the offline contract with:

```powershell
deno test --allow-read=supabase supabase/drift/verify_manifest_test.ts
```

The verifier checks project identity, migration filenames, exact recovered
migration statements, deployed function inventory, JWT configuration, bundle
metadata, recovered source lengths, and local entrypoint reachability. It does
not contact or mutate production.

`remote_state_2026-08-09.json` and `remote_snapshots/` are historical captures.
They remain for provenance only and must not override the current GhostHeart5
baseline. The production implementations recovered into `supabase/functions/`
are authoritative until a later read-only capture and reviewed deployment
supersede them.

Refresh drift evidence only through read-only project, migration, function,
table, and advisor calls. Never apply a migration or deploy a function merely
to refresh an inventory. Before any authorized production change, compare the
linked project ref, run local checks, run `supabase db push --dry-run`, and stop
if the proposed target or diff is not exact.
