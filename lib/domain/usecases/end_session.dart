import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';

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
      await prog.saveProgression(
        current.copyWith(xp: current.xp + ProgressionPolicy.sessionXp),
      );
    }
  }
}
