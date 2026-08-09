# ChronoSpark Maestro Framework

## Purpose
This Maestro suite validates production-critical user workflows for ChronoSpark without changing application logic.

## Execution Order
1. Smoke suite
2. Onboarding and authentication suites
3. Core product suites (planner, timeline, AI surfaces)
4. Monetization and settings suites
5. Full release suite

## Required Environment Variables
1. MAESTRO_EMAIL
2. MAESTRO_PASSWORD

## Run Examples
1. maestro test maestro/smoke/_suite_smoke.yaml
2. maestro test maestro/release/release_full_validation.yaml

## Notes
1. Flows intentionally use real visible labels from current UI.
2. Some monetization flows validate gate behavior and route visibility; store checkout completion requires sandbox store configuration.
