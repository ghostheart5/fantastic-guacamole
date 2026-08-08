import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Progression
///
/// Administrative level override for restore/import. Gameplay level is derived
/// from XP.
/// Administrative level override (restore/import/support correction).
///
/// Gameplay must never call this — level is derived from cumulative XP by
/// [ProgressionPolicy] via `AwardXp`. Kept because restore/import flows need a
/// way to set a level directly.
class UpdateLevel {
  UpdateLevel(this.repository);

  final IProgressionRepository repository;

  Future<ProgressionEntity> call(int level) async {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'Level must be at least 1');
    }
    final ProgressionEntity current =
        await repository.getProgression() ?? const ProgressionEntity();
    final ProgressionEntity updated = current.copyWith(level: level);
    await repository.saveProgression(updated);
    return updated;
  }
}
