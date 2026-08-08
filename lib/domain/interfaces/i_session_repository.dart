import 'package:fantastic_guacamole/domain/entities/session_entity.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Sessions/focus
///
/// Bound to SessionRepository; focus-session UI not built yet.
abstract class ISessionRepository {
  Future<void> startSession(SessionEntity session);
  Future<void> endSession(String sessionId, DateTime endedAt);
  Future<void> pauseSession(String sessionId, DateTime pausedAt);
  Future<void> resumeSession(String sessionId, DateTime resumedAt);
  Future<List<SessionEntity>> getSessionsForTask(String taskId);

  /// Required so `EndSession` can enforce [SessionPolicy.canEnd] — without it
  /// an already-ended session could be ended repeatedly, re-awarding XP.
  Future<SessionEntity?> getSessionById(String sessionId);
}
