import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/domain/progression/progression_calculator.dart';

class EndSession {
  EndSession(this.repository, {this.progressionRepo});

  final ISessionRepository repository;
  final IProgressionRepository? progressionRepo;

  Future<void> call(String sessionId, DateTime endedAt) async {
    await repository.endSession(sessionId, endedAt);

    final IProgressionRepository? prog = progressionRepo;
    if (prog != null) {
      final ProgressionEntity current =
          await prog.getProgression() ?? const ProgressionEntity();
      final int newXp = current.xp + ProgressionPolicy.sessionXp;
      final ProgressionCalculation progression = const ProgressionCalculator()
          .calculate(xp: newXp);
      await prog.saveProgression(
        current.copyWith(
          xp: progression.xp,
          level: progression.effectiveLevel,
        ),
      );
    }
  }
}
