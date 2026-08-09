# Staging Migration Application Checklist

**Review checklist only. DO NOT RUN ANY MIGRATION COMMAND UNTIL HUMAN APPROVES.**

- [ ] Confirm the target project is staging: `pxtjkwfedrtnxuihtdox`.
- [ ] Confirm this target is not production.
- [ ] Confirm function discovery shows the expected functions are missing.
- [ ] Confirm schema discovery shows empty or missing expected objects, or identifies no conflicting manually created objects.
- [ ] Confirm [MIGRATION_SAFETY_REVIEW.md](MIGRATION_SAFETY_REVIEW.md) has no destructive blocker for the actual staging data state.
- [ ] Confirm backups or export are unnecessary because staging is disposable; otherwise document the existing staging data and obtain a specific backup plan.
- [ ] Obtain explicit human approval for migration application.

## Future Command

**DO NOT RUN UNTIL HUMAN APPROVES.** After every checklist item is complete and a final target check passes, the possible command is:

```powershell
npx supabase db push
```

This checklist does not authorize `migration up`, `db reset`, seed SQL, RLS mutation tests, Edge Function deployments, or production access.
