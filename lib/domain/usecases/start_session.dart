import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/policies/session_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Sessions/focus
///
/// Registered as startSessionUseCaseProvider; focus-session UI not built yet.
/// Gated by SessionPolicy.canStart.
/// Starts a focus session.
///
/// Session XP is deliberately NOT awarded here — `EndSession` is the single
/// lifecycle point for session XP. Awarding on both ends double-paid every
/// session and made XP farmable by starting sessions that were never finished.
class StartSession {
  StartSession(this.repo, {this.generateSiDecision});

  final ISessionRepository repo;
  final GenerateSiDecision? generateSiDecision;

  Future<void> call(SessionEntity session) async {
    if (session.id.trim().isEmpty) {
      throw ArgumentError.value(session.id, 'session.id', 'must not be blank');
    }

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
  }
}
