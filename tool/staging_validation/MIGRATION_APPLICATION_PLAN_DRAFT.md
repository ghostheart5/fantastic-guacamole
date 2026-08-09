# Migration Application Plan Draft

**DRAFT ONLY - DO NOT RUN YET.**

## Current Finding

Staging appears to have no remote migrations applied: the confirmed staging migration list contains local migrations with blank Remote values.

## Required Before Applying

- Confirm staging is disposable or safe to mutate.
- Review schema and function discovery output.
- Review existing manually created objects, if any.
- Decide whether to apply migrations through GitHub Actions or the CLI.
- Confirm no production project is targeted.

## Forbidden Until Explicit Approval

- `db push`
- `migration up`
- `db reset`
- Seed SQL
- RLS mutation tests

## Possible Future Command

**DO NOT RUN YET.** Only after explicit approval and a final safety check:

```powershell
npx supabase db push
```

## Decision Guidance

If staging is intentionally empty, migration application can likely proceed after approval and a final safety check.

If staging has manually created objects, create compatibility migrations instead of dropping and recreating objects.
