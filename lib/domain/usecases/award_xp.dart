import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Progression
///
/// The single persisted XP-award path. Used directly by CompleteTask and
/// Completion handling.
/// The single persisted XP-award path.
///
/// Every gameplay XP award must go through this use case. It rejects negative
/// awards, keeps XP cumulative, recomputes the level from [ProgressionPolicy],
/// and persists the result. Writing `copyWith(xp: ...)` directly is a bug: it
/// leaves [ProgressionEntity.level] frozen.
class AwardXp {
  const AwardXp(this.repository);

  final IProgressionRepository repository;

  Future<ProgressionEntity> call(int amount) async {
    if (amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'XP award cannot be negative',
      );
    }
    final ProgressionEntity current =
        await repository.getProgression() ?? const ProgressionEntity();
    final ProgressionEntity updated = current.awardXp(amount);
    await repository.saveProgression(updated);
    return updated;
  }
}
