# ChronoSpark Maestro Framework

## Purpose
This Maestro suite validates production-critical user workflows for ChronoSpark without changing application logic.

## Execution levels

Every flow receives `APP_ID` from the runner. The runner verifies the package
name of the actual generated APK before install, clears only the isolated test
package by default, and writes JUnit, Maestro debug output, logcat, and a
final device screenshot under `artifacts/maestro/`. A nonzero Maestro exit is
always a failure; a partial JUnit report cannot override it.

1. **PR smoke** — `maestro/levels/pr_smoke.yaml`; app launch, authentication,
   Nexus, Timeline, and Creator input guard.
2. **Nightly feature E2E** — `maestro/levels/nightly_feature_e2e.yaml`; all
   feature suites plus regression chains, on the isolated mock account.
3. **Pre-release full validation** —
   `maestro/levels/pre_release_full_validation.yaml`; uses the dedicated
   `maestro-onboarding` build and includes onboarding, Nexus, Creator,
   Timeline, Smart Planner, SI Console, Trajectory, Progression, Profile,
   Settings, notifications, and regression coverage. Sandbox subscriptions
   remain a separate gate.
4. **Sandbox subscription validation** —
   `maestro/levels/sandbox_subscription_validation.yaml`; requires a configured
   sandbox store account and must never be pointed at a production account.

Creator is the only creation suite: task, goal, routine, and note flows live
under `maestro/creator`. “Planner” refers only to **Smart Planner**, the
separate guidance surface. Smart Planner and SI Console have separate suites
and an isolation regression flow; no Maestro flow connects or shares chat UI
state between them.

## Configuration
All flows consume `APP_ID`; do not hard-code an Android package in individual
flows. `scripts/run_maestro.ps1` supplies the package for the selected profile.

`MAESTRO_EMAIL` and `MAESTRO_PASSWORD` are required for staging and production
probes. The isolated Maestro profile uses debug-only mock credentials and never
enables production bypasses.

## Run Examples
1. `pwsh ./scripts/run_maestro.ps1 -Profile maestro -Level pr-smoke`
2. `pwsh ./scripts/run_maestro.ps1 -Profile maestro -Level nightly-feature-e2e`
3. `pwsh ./scripts/run_maestro.ps1 -Profile maestro-onboarding -Level pre-release-full`
4. `pwsh ./scripts/run_maestro.ps1 -Profile maestro -Level sandbox-subscriptions`

## Notes
1. Navigation flows prefer stable Flutter semantics identifiers.
2. Each alternate state is explicitly asserted. There are no optional critical
   navigation or result assertions in this tree.
3. Subscription validation is a sandbox-only gate. It must not run with the
   `staging` or `production` profile and does not claim store-purchase success
   unless the sandbox UI returns the required state.
4. Onboarding uses the dedicated `maestro-onboarding` build because standard
   Maestro mode intentionally marks onboarding complete for deterministic core
   feature flows.
