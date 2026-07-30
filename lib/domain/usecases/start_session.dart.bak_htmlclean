import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/domain/policies/session_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';

class StartSession {
  StartSession(this.repo, {this.generateSiDecision, this.progressionRepo});

  final ISessionRepository repo;
  final GenerateSiDecision? generateSiDecision;
  final IProgressionRepository? progressionRepo;

  Future<void> call(SessionEntity session) async {
    SessionEntity finalSession = session;

    final GenerateSiDecision? si = generateSiDecision;
    if (si != null) {
      final siDecision = await si('start focus session');
      if (siDecision.shouldSimplify) {
        final int shortenedMinutes = siDecision.recommendedFocusMinutes;
        finalSession = SessionEntity(
          id: session.id,
          taskId: session.taskId,
          startedAt: session.startedAt,
          endedAt: session.endedAt,
          plannedDuration: Duration(minutes: shortenedMinutes),
        );
      }
    }

    if (!SessionPolicy.canStart(finalSession)) {
      throw Exception('Cannot start session');
    }
    await repo.startSession(finalSession);

    // Award flat XP on session start (committed intent)
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
