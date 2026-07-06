import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';

class UpdateXp {
  UpdateXp(this.repository);

  final IProgressionRepository repository;

  Future<ProgressionEntity> call(int xp) async {
    final ProgressionEntity current =
        await repository.getProgression() ?? const ProgressionEntity();
    final ProgressionEntity updated = current.copyWith(xp: xp);
    await repository.saveProgression(updated);
    return updated;
  }
}
