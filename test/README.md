# ChronoSpark Test Architecture

ChronoSpark uses layered, deterministic tests. A passing suite is necessary but
not sufficient: critical persistence, authentication, account deletion,
planning, progression, and recovery paths must also satisfy the coverage guard.

## Automated Layers

- `test/domain`: pure entities, policies, value objects, and use cases.
- `test/data`: repositories, storage, service contracts, corruption recovery,
  and failure injection.
- `test/state`: Riverpod controllers/providers, hydration races, persistence,
  and lifecycle behavior.
- `test/engine`: planning, scoring, learning, SI, assistant, and guardrail logic.
- `test/features` and `test/ui`: widget behavior, accessibility semantics,
  keyboard behavior, error states, and reviewed golden baselines.
- `test/integration`: fast cross-layer flows that run in the Flutter test VM.
- `integration_test`: application-root journeys reserved for later
  build/device-capable validation.
- `test/security` and `test/architecture`: fail-closed configuration, schema,
  dependency-boundary, and product-canon contracts.
- `supabase/functions/**/*_test.ts`: Deno tests for Edge Function pure logic.
- `.maestro`: device-level end-to-end flows. YAML and referenced subflows are
  validated in CI; device execution remains a release/UAT gate.

## Determinism Rules

- Inject clocks or use fixed UTC timestamps for boundary assertions.
- Use seeded inputs for generative/fuzz grids and record any failing seed.
- Do not use wall-clock sleeps for synchronization. Widget pumps are allowed
  only to advance Flutter's fake clock or settle a documented animation.
- Do not swallow exceptions or accept multiple incompatible outcomes.
- Do not use `--update-goldens` in validation CI. Golden regeneration is an
  explicit, manually dispatched workflow and requires review of the images.
- Every test owns and disposes its provider container, mock handler, temporary
  directory, and persistent state.

## Local Non-Build Gate

```powershell
Copy-Item .env.example .env -Force
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --fatal-infos
dart run tool/validate_maestro_flows.dart
deno check supabase/functions/ai-proxy/index.ts
deno check supabase/functions/account-delete/index.ts
deno check supabase/functions/verify-receipt/index.ts
deno test supabase/functions/_shared/storage_cleanup_test.ts
flutter test test --coverage --concurrency=1
./scripts/coverage_guard.ps1
```

These commands do not build a distributable application or launch a device.
`integration_test`, Maestro execution, golden regeneration, and release builds
are deliberately separate gates.

## Shared Test Support

- `test/helpers`: small repository/storage fakes and entity builders.
- `test/support/golden_harness.dart`: deterministic surface sizing and fonts.
- Prefer the real lightweight repository with isolated temporary storage when
  persistence behavior is the subject of the test.

## Manual Validation

The executable-human scenarios, prerequisites, evidence rules, failure
indicators, and recovery steps are in
`docs/testing/CHRONOSPARK_UAT_MATRIX.md`.
