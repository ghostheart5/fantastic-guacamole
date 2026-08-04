import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Progression
///
/// Absolute XP set for restore/import/admin. Gameplay must use AwardXp.
/// Sets cumulative XP to an absolute value (restore/import/admin correction).
///
/// This is NOT the gameplay award path — use `AwardXp` for that. Level is still
/// recomputed from [ProgressionPolicy] so the two can never disagree.
class UpdateXp {
  UpdateXp(this.repository);

  final IProgressionRepository repository;

  Future<ProgressionEntity> call(int xp) async {
    if (xp < 0) {
      throw ArgumentError.value(xp, 'xp', 'XP cannot be negative');
    }
    final ProgressionEntity current =
        await repository.getProgression() ?? const ProgressionEntity();
    final ProgressionEntity updated = current.copyWith(
      xp: xp,
      level: ProgressionPolicy.levelFromXp(xp),
    );
    await repository.saveProgression(updated);
    return updated;
  }
}
