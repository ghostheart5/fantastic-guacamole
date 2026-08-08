import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Sessions/focus
///
/// Registered as resumeSessionUseCaseProvider; awaiting focus-session UI.
class ResumeSession {
  ResumeSession(this.repository);

  final ISessionRepository repository;

  Future<void> call(String sessionId, DateTime resumedAt) {
    return repository.resumeSession(sessionId, resumedAt);
  }
}
