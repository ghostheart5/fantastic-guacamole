# Active Compatibility Register

ChronoSpark does not mark an API deprecated while production code still relies
on it. A same-package deprecation warning that must be broadly suppressed is a
false static-quality signal, not a migration plan.

The machine-readable authority is
`tool/active_compatibility_manifest.json`. It records the owner, canonical
replacement, and objective removal criterion for each active bridge:

- `Task` preserves the historical constructor and non-null duration contract
  while `TaskEntity` adoption continues.
- `TimeBlock` preserves planner-facing `completed` and non-null `taskId`
  semantics over `CalendarEntryEntity`.
- `SIAIService` preserves the agent-facing response adapter over
  `SIEngineService`.
- `SyntheticIntelligenceEngine` preserves the legacy cognitive-input adapter
  over `SIEngineService`.

`test/quality/compatibility_manifest_contract_test.dart` fails if an entry is
missing, unowned, lacks an exit criterion, or is prematurely annotated as
deprecated. Once an entry has no production consumers, it must be migrated and
deleted instead of left as indefinite compatibility code.
