import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/policies/session_policy.dart';

class StartSession {
  StartSession(this.repo);

  final ISessionRepository repo;

  Future<void> call(SessionEntity session) async {
    if (!SessionPolicy.canStart(session)) {
      throw Exception('Cannot start session');
    }
    await repo.startSession(session);
  }
}
