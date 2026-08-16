# Human Approval Before `db push`

**DO NOT RUN UNTIL EVERY CHECKBOX IS COMPLETE.**

- [ ] I confirm `RETIRED_STAGING_PROJECT` is ChronoSpark staging.
- [ ] I confirm this is not production.
- [ ] I confirm the 2 Auth users are staging-only or disposable.
- [ ] I confirm Storage has 0 buckets.
- [ ] I confirm Storage has 0 objects.
- [ ] I confirm expected ChronoSpark tables are absent.
- [ ] I confirm expected ChronoSpark functions are absent.
- [x] `public.rls_auto_enable` review is documented: it is a non-conflicting untracked helper and should remain in place.
- [ ] I reviewed [MIGRATION_SAFETY_REVIEW.md](MIGRATION_SAFETY_REVIEW.md).
- [ ] I understand `20260717170000_secure_user_daily_metrics.sql` contains destructive markers.
- [ ] I accept the destructive markers as safe for this staging project because target app data is absent.
- [ ] I understand `db push` will mutate staging.
- [ ] I approve applying tracked migrations to staging only.
- [ ] I understand production release remains blocked after `db push` until post-migration validation passes.

## Future Manual Command

**DO NOT RUN UNTIL EVERY CHECKBOX IS COMPLETE.**

```powershell
npx supabase db push
```

This approval does not authorize `migration up`, `db reset`, deployment, seed data, RLS mutation tests, production access, or service-role key use.
