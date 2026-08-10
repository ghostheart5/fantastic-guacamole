# ChronoSpark Maestro Framework

## Purpose
This Maestro suite validates production-critical user workflows for ChronoSpark without changing application logic.

## Execution Order
1. Smoke suite
2. Onboarding and authentication suites
3. Core product suites (planner, timeline, AI surfaces)
4. Monetization and settings suites
5. Full release suite

## Configuration
All flows consume `APP_ID`; do not hard-code an Android package in individual
flows. `scripts/run_maestro.ps1` supplies the package for the selected profile.

`MAESTRO_EMAIL` and `MAESTRO_PASSWORD` are required for staging and production
probes. The isolated Maestro profile uses debug-only mock credentials and never
enables production bypasses.

## Run Examples
1. `pwsh ./scripts/run_maestro.ps1 -Profile maestro`
2. `pwsh ./scripts/run_maestro.ps1 -Profile maestro-onboarding -Suite maestro/onboarding/_suite_onboarding.yaml`
3. `pwsh ./scripts/run_maestro.ps1 -Profile staging -Suite maestro/release/release_full_validation.yaml`
4. `pwsh ./scripts/run_maestro.ps1 -Profile production -Suite maestro/release/production_probe.yaml -SkipBuild`

## Notes
1. Navigation flows prefer stable Flutter semantics identifiers.
2. Some monetization flows validate gate behavior and route visibility; store checkout completion requires sandbox store configuration.
3. Production probes are non-destructive and must never reset accounts, create purchases, or delete data.
4. Onboarding uses the dedicated `maestro-onboarding` build because standard
   Maestro mode intentionally marks onboarding complete for deterministic core
   feature flows.
