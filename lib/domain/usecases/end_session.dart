import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/domain/policies/session_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/award_xp.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Sessions/focus
///
/// Registered as endSessionUseCaseProvider. Single lifecycle point for session
/// XP; gated by SessionPolicy.canEnd.
/// Ends a focus session and awards session XP.
///
/// This is the single lifecycle point for session XP. The [SessionPolicy.canEnd]
/// gate is what makes that safe: without it an already-ended session could be
/// ended repeatedly, re-awarding XP each time.
class EndSession {
  EndSession(this.repository, {this.progressionRepo});

  final ISessionRepository repository;
  final IProgressionRepository? progressionRepo;

  Future<void> call(String sessionId, DateTime endedAt) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'must not be blank');
    }

    final SessionEntity? session = await repository.getSessionById(sessionId);
    if (session == null) {
      throw StateError('Session not found');
    }
    if (!SessionPolicy.canEnd(session)) {
      throw StateError('Session already ended');
    }

    await repository.endSession(sessionId, endedAt);

    final IProgressionRepository? prog = progressionRepo;
    if (prog != null) {
      await AwardXp(prog).call(ProgressionPolicy.sessionXp);
    }
  }
}
