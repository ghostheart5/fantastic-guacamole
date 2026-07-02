import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';

class EndSession {
  EndSession(this.repository);

  final ISessionRepository repository;

  Future<void> call(String sessionId, DateTime endedAt) {
    return repository.endSession(sessionId, endedAt);
  }
}
