import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Sessions/focus
///
/// Registered as pauseSessionUseCaseProvider; awaiting focus-session UI.
class PauseSession {
  PauseSession(this.repository);

  final ISessionRepository repository;

  Future<void> call(String sessionId, DateTime pausedAt) {
    return repository.pauseSession(sessionId, pausedAt);
  }
}
