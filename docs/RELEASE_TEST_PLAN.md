# ChronoSpark Release Reliability Plan

This plan defines the current non-build automated gate and the validation that
must remain separate because it requires a built application or physical
device. It replaces the former list of proposed tests whose paths no longer
matched the repository.

## Current Automated Estate

- Unit/widget/contract test files: see the live inventory in `test/`.
- Fast cross-layer tests: `test/integration/`.
- Application-root integration journeys: `integration_test/`.
- Supabase Edge Function tests: `supabase/functions/**/*_test.ts`.
- Maestro flows: `.maestro/flows/`, with static YAML/subflow validation in CI.
- Golden comparisons: authentication at 320/500 px and Nexus at 320/375/500
  px. Each committed PNG is referenced by a `matchesGoldenFile` assertion; a
  PNG or update workflow without an executable assertion is not evidence.
- Coverage enforcement: `scripts/coverage_guard.ps1 -Mode ratchet` blocks
  regression from the measured baseline; the default `-Mode target` audits the
  higher release-quality destination and remains intentionally strict.
- Canonical commands and isolation rules: `test/README.md`.

Counts are intentionally not frozen in this document. CI discovers the live
suite so adding or moving tests cannot silently make a hand-maintained count
authoritative.

## Required Pull-Request Gate

The primary CI workflow must pass all of these without creating a distributable
build or launching a device:

1. Formatting verification for `lib`, `test`, and `integration_test`.
2. Secret scanning.
3. Flutter analyzer with informational diagnostics treated as failures.
4. Architecture boundary validation.
5. Maestro YAML and `runFlow` target validation.
6. Deno type checks for every Edge Function.
7. Deno unit tests for extracted Edge Function logic.
8. Flutter `test/` execution with serialized isolation and coverage.
9. A non-zero golden comparison contract. CI must fail before the test run if
   the two named golden files contain zero `matchesGoldenFile` assertions.
10. Overall, layer, and release-critical coverage ratchet floors. The target
   audit remains required before claiming the coverage destination is met.

Validation CI is read-only. It must never update golden files, commit, or push.
Golden regeneration remains a manually dispatched and reviewable workflow.
Regeneration is not a passing comparison: the same baselines must subsequently
pass without `--update-goldens`.
The named app-only goldens use the default exact comparator. Their harness
loads app/icon fonts and disables supported animations; a percentage tolerance
must not replace deterministic setup or be reported as exact evidence.

## Release-Critical Automated Flows

### Authentication and startup

- `integration_test/app_startup_test.dart`
- `integration_test/auth_flow_integration_test.dart`
- `test/features/auth/auth_signin_chain_test.dart`
- `test/data/services/auth_service_delete_account_test.dart`

### Persistence, recovery, and offline behavior

- `integration_test/persistence_recovery_test.dart`
- `test/integration/offline_sync_roundtrip_integration_test.dart`
- `test/state/services/offline_sync_queue_service_test.dart`
- `test/state/services/app_recovery_service_test.dart`
- `test/data/services/backup_service_test.dart`
- `test/data/services/sync_service_test.dart`

### Tasks, planning, and intelligence

- `test/integration/task_lifecycle_test.dart`
- `test/integration/si_console_flow_test.dart`
- `test/integration/si_engine_guardrails_integration_test.dart`
- `test/domain/usecases/smart_planner_usecases_test.dart`
- `test/state/controllers/smart_planner_query_controller_test.dart`
- `test/features/home/smart_planner_screen_test.dart`

### Creator and connected feature chain

- `test/features/creator/dynamic_form_test.dart`
- `test/state/providers/creator_provider_type_mapping_test.dart`
- `test/domain/usecases/feature_chain_usecases_test.dart`
- `test/features/nexus/nexus_navigation_test.dart`
- `test/features/feature_screen_smoke_test.dart`

### Progression, state races, and integrity

- `test/domain/policies/progression_curve_test.dart`
- `test/domain/policies/progression_policy_test.dart`
- `test/state/controllers/profile_level_migration_test.dart`
- `test/state/controllers/profile_persistence_race_test.dart`
- `test/state/providers/identity_provider_race_test.dart`
- `test/data/repositories/goal_repository_corruption_test.dart`

### Security, privacy, and configuration

- `test/security/security_hardening_test.dart`
- `test/security/supabase_data_boundary_contract_test.dart`
- `test/config/production_gates_test.dart`
- `test/product_canon/product_terminology_contract_test.dart`
- `supabase/functions/_shared/storage_cleanup_test.ts`

## Device and Build Validation

The following are not represented as passed by the non-build suite:

- signed Android App Bundle creation and install;
- application-root `integration_test/` execution on target devices;
- Maestro release-critical and destructive flows;
- Play Billing license-account purchase and restore;
- microphone, notification, deep-link, and audio-focus behavior;
- Firebase/Supabase behavior with production credentials and policies;
- tablet, foldable, orientation, accessibility, performance, and lifecycle UAT;
- visual review before accepting regenerated goldens.

Execute these using `docs/testing/CHRONOSPARK_UAT_MATRIX.md` and retain the
required evidence. A deferred device scenario is never counted as an automated
pass.

Every release report must keep source/static, host test, physical-device,
human-UAT, and excluded external evidence in separate sections. A host widget,
integration, or golden PASS cannot be copied into the physical-device column.

## Definition of Done

- The complete non-build gate passes twice from independent test processes.
- No unexpected skips, swallowed failures, or CI-generated source changes.
- CI coverage ratchets pass, critical target files appear in the report, and
  target-mode debt is explicitly recorded rather than hidden or lowered.
- Remaining failures are classified with owner, environment, and exact rerun.
- Physical-device UAT and release builds are completed later on the signed
  release candidate before any store submission.
