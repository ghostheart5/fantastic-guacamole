<style>
a {
    text-decoration: none;
    color: #464feb;
}
tr th, tr td {
    border: 1px solid #e6e6e6;
}
tr th {
    background-color: #f5f5f5;
}
</style>

## Which SI engine files should be public vs internal

Treat `engine/si` as a private subsystem. The runtime is intentionally small and behavior-first.

### Public engine facade files

The canonical runtime entry point is:
- engine/si/si_engine_service.dart

Use `engine/si/api.dart` for shared SI models and deterministic offline engines already consumed outside the subsystem. Existing direct imports are frozen by `test/architecture/si_public_boundary_test.dart`; new public paths require an explicit boundary change.

`si_ai_service.dart` and `synthetic_intelligence_engine.dart` remain deprecated compatibility adapters only. They must delegate to `SIEngineService`.

### Internal engine modules

These remain internal and must not be imported by UI/state/data directly:
- si_engine.dart
- si_output_bundle.dart
- si_output_validator.dart
- prediction_engine.dart
- core/*

The removed unreachable scaffolding is recoverable through `docs/audits/si_unreachable_preservation_20260819.md`.
