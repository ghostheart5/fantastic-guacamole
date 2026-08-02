import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';

class UpdateLevel {
  UpdateLevel(this.repository);

  final IProgressionRepository repository;

  Future<ProgressionEntity> call(int level) async {
    final ProgressionEntity current =
        await repository.getProgression() ?? const ProgressionEntity();
    // Direct level updates are manual/admin-style and may intentionally diverge from XP-derived level.
    final ProgressionEntity updated = current.copyWith(level: level);
    await repository.saveProgression(updated);
    return updated;
  }
}
