import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';

class UpdateStreak {
  UpdateStreak(this.repository);

  final IProgressionRepository repository;

  Future<ProgressionEntity> call(int streak) async {
    final ProgressionEntity current =
        await repository.getProgression() ?? const ProgressionEntity();
    final ProgressionEntity updated = current.copyWith(streak: streak);
    await repository.saveProgression(updated);
    return updated;
  }
}
