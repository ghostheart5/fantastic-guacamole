import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';

class PauseSession {
  PauseSession(this.repository);

  final ISessionRepository repository;

  Future<void> call(String sessionId, DateTime pausedAt) {
    return repository.pauseSession(sessionId, pausedAt);
  }
}
