import 'package:fantastic_guacamole/domain/entities/session_entity.dart';

abstract class ISessionRepository {
  Future<void> startSession(SessionEntity session);
  Future<void> endSession(String sessionId, DateTime endedAt);
  Future<void> pauseSession(String sessionId, DateTime pausedAt);
  Future<void> resumeSession(String sessionId, DateTime resumedAt);
  Future<List<SessionEntity>> getSessionsForTask(String taskId);
}
