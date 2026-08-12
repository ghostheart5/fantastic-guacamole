# ChronoSpark Git Operating Model After Recovery

Use a single protected `main` as the releasable line after a separately approved clean-integration effort. Do not add a permanent `develop` branch unless delivery evidence later demonstrates a durable need.

- Branches: `feature/<ticket>-<slug>`, `fix/<ticket>-<slug>`, `docs/<ticket>-<slug>`, and narrowly scoped `chore/<ticket>-<slug>`.
- Lifetime: short-lived; one coherent change per branch and PR.
- Merge policy: PR review, required CI, linear/squash merge as repository policy determines; no direct pushes to protected `main`.
- CI: analysis, relevant tests, secret scanning, and release checks must pass before merge. A failed or unavailable check blocks merge unless an explicitly documented emergency exception is approved.
- Stale branches: review at a defined cadence; preserve first, then delete only after reachability/unique-history proof and owner approval.
- Release tags: annotate immutable, validated releases (for example `vX.Y.Z`) from protected `main` only.
- Rollback: retain release tags and deploy only artifacts traceable to a tag; rollback means redeploying a previous validated tag, not rewriting Git history.
- Recovery branches: retain until their unique history has been classified and any selected work has been independently preserved.
