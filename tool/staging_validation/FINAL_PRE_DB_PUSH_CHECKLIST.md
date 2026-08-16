# Final Pre-`db push` Checklist

**DO NOT RUN UNTIL EVERY CHECKBOX ABOVE IS COMPLETE AND HUMAN APPROVES.**

- [ ] Confirm `RETIRED_STAGING_PROJECT` is ChronoSpark staging.
- [ ] Confirm the 2 Auth users are staging test users or disposable.
- [ ] Confirm storage bucket count is 0.
- [ ] Confirm storage object count is 0.
- [ ] Confirm expected ChronoSpark app tables are absent.
- [ ] Confirm expected ChronoSpark functions are absent.
- [x] `public.rls_auto_enable` reviewed and documented as a non-conflicting untracked helper; leave it in place.
- [ ] Confirm migration safety review findings are accepted.
- [ ] Confirm `20260717170000_secure_user_daily_metrics.sql` destructive markers are safe because target data is absent.
- [ ] Confirm no production project is linked.
- [ ] Confirm human approval before `db push`.

## Future Manual Command

**DO NOT RUN UNTIL EVERY CHECKBOX ABOVE IS COMPLETE AND HUMAN APPROVES.**

```powershell
npx supabase db push
```

This checklist does not authorize `migration up`, `db reset`, deployment, seed data, RLS mutation tests, or production access.
