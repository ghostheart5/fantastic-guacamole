import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

class UpdateXp {
  UpdateXp(this.repository);

  final IProgressionRepository repository;

  Future<ProgressionEntity> call(int xp) async {
    final ProgressionEntity current =
        await repository.getProgression() ?? const ProgressionEntity();
    final int safeXp = xp < 0 ? 0 : xp;
    final ProgressionEntity updated = current.copyWith(
      xp: safeXp,
      level: ProgressionPolicy.levelFromXp(safeXp),
    );
    await repository.saveProgression(updated);
    return updated;
  }
}
