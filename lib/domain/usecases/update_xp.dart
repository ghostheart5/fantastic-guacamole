import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/progression/progression_calculator.dart';

class UpdateXp {
  UpdateXp(this.repository);

  final IProgressionRepository repository;

  Future<ProgressionEntity> call(int xp) async {
    final ProgressionEntity current =
        await repository.getProgression() ?? const ProgressionEntity();
    final ProgressionCalculation progression = const ProgressionCalculator()
        .calculate(xp: xp);
    final ProgressionEntity updated = current.copyWith(
      xp: progression.xp,
      level: progression.effectiveLevel,
    );
    await repository.saveProgression(updated);
    return updated;
  }
}
