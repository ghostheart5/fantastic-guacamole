# Model Layer Convention

This repository uses the following model naming and placement convention:

- Domain entities are canonical business models and should use stable names in `lib/domain/entities`.
- Data transfer records and persistence DTOs belong in `lib/data/models`.
- Avoid creating parallel pairs like `name.dart` and `name_entity.dart` in `lib/domain/entities`.
- Current baseline still includes many `*_entity.dart` domain names; the immediate guardrail is focused on preventing duplicate pairs.

## Current Legacy Exceptions

The following duplicate pairs exist today and are treated as temporary legacy exceptions while migration is planned:

- `lib/domain/entities/task.dart` and `lib/domain/entities/task_entity.dart`
- `lib/domain/entities/calendar_entry.dart` and `lib/domain/entities/calendar_entry_entity.dart`

Do not add new duplicate pairs.

## Migration Direction

For each legacy pair:

1. Keep one canonical domain entity name in `lib/domain/entities`.
2. Move persistence-specific fields/shapes into `lib/data/models/*_record.dart`.
3. Add explicit mappers in `lib/data/local` or `lib/data/mappers`.
4. Remove the legacy duplicate after all usages are migrated.

## Guardrail

The architecture checker enforces:

- No new duplicate basename pairs (`x.dart` + `x_entity.dart`) in `lib/domain/entities` except explicit legacy allowlist.

Run guardrail:

- VS Code task: `check-architecture`
- Script: `check_architecture.ps1`
