# TEST PRIORITY 3 - Exploratory and Long-Tail Hardening

Date: 2026-08-03
Project: ChronoSpark Smart Planner (Flutter)

## Scope
Priority 3 covers exploratory and long-tail behavior intended to expose non-deterministic defects, edge input issues, and weak guardrails.

## Exploratory Areas

1. Rapid navigation switching and repeated back actions
2. Long session continuity across multiple feature surfaces
3. Unusual prompt payloads in AI interfaces
4. Repeated open and close of notifications and settings dialogs
5. Legacy route compatibility checks and redirects

## Known Open Risks

1. Restore purchases UI path appears incomplete for explicit restore action
2. Several surfaces rely on text selectors only and should gain stable keys for deterministic automation
3. Some resilience paths require network and store sandbox controls not covered by local deterministic Maestro alone

## P3 Test Inventory (Weekly)

1. maestro/regression/regression_navigation_chain.yaml
2. maestro/regression/regression_ai_surfaces.yaml
3. maestro/regression/regression_monetization_chain.yaml
4. maestro/release/release_full_validation.yaml

## Exit Criteria

1. No high-severity crashes in 3 weekly runs
2. No legacy route regressions
3. No unresolved data-loss behavior during exploratory path checks
