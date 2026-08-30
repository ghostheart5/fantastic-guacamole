# ChronoSpark Launch Readiness Rollback

## Baseline Recovery

- Baseline commit: `46494890aa5a8ddbec7c6a3c303fc9aa845651b4`
- Complete local bundle: `C:\Users\keegan radetski\ChronoSpark-snapshots\20260829-2040-readiness-4649489\repository.bundle`
- Bundle SHA-256: `EB9414A71782F523A03A2B07CE9DC2693E518CD9CF626FC6D7C6E2AE8C006417`
- Snapshot manifest SHA-256: `DD010134877D70E906FF7776521667052100DF2F4439077B010E8BF7F190EF4D`
- Original checkout remains on `integration/production-candidate-hardening-20260827` with its pre-existing Gradle modification preserved.

## Rules

- Never use `git reset --hard`, `git clean`, force push, history rewriting, or branch deletion.
- Roll back a completed phase with a new `git revert <phase-commit>` commit after reviewing data compatibility.
- Do not roll back a schema migration by deleting data. Use an approved forward migration or reversible compatibility step.
- Do not revert user-owned changes or the original checkout's `android/gradle.properties` modification.
- A containment rollback must not silently re-enable cloud restore/sync, subscriptions, external AI, credit spending, or telemetry.

## Phase 0 Rollback

- Commit: `68bc277b936a49e890a4c1d94bdc05d5a087353d`.
- Data migration: none.
- User-data mutation: none.
- Method: create a reviewed `git revert 68bc277b936a49e890a4c1d94bdc05d5a087353d` commit, then rerun containment tests.
- Safety condition: cloud restore/sync, subscriptions, external AI, credit spending, telemetry, and inferred identity must remain unreachable after any rollback. If reverting would re-enable them, stop and use a forward containment fix instead.

## Phase 1 Rollback Plan

- Phase 1 will use separate local commits for consent/context, startup, tutorial/Timeline, auth/navigation, and evidence updates.
- Consent rollback is permitted only if emotional-state and governed-memory use still fail closed by default and after restart. Existing memory receipts must remain reviewable and deletable even when recall is disabled.
- Startup rollback is permitted only if both initialization and cancellation quiescence remain bounded and account-scoped storage never opens while the timed-out source is still active.
- Tutorial/Timeline rollback is permitted only if a visit or button tap cannot falsely record a saved-item or Timeline-review milestone.
- Auth/navigation rollback is permitted only if Privacy and Terms remain reachable before account creation and a validated protected `returnTo` survives login and onboarding.
- No Phase 1 rollback may re-enable a Phase 0 contained capability.

## Phase 8 Rollback Plan

- Revert the Phase 8 app and Edge checkpoint only with a new reviewed revert commit, then rerun containment, billing/paywall tests, Edge tests, analyzer, and release guards.
- A source rollback must leave subscriptions, paid credit plans, external AI, and credit spending disabled.
- Do not delete purchase bindings, opaque billing principals, terminal purchase states, entitlement events, allowance grants, credit transactions, or AI settlement rows.
- If the Phase 8 migration has been applied anywhere, do not reverse it with destructive DDL or manual data edits. Use an approved forward compatibility migration that preserves terminal authority and hashed lineage.
- Do not deploy, migrate, alter Play configuration, or rotate secrets as part of a local rollback.
