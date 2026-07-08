import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/pause_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PauseSession delegates to repository', () async {
    final _FakeSessionRepository repository = _FakeSessionRepository();
    final DateTime pausedAt = DateTime.utc(2026, 7, 5, 10, 30);

    await PauseSession(repository).call('session-1', pausedAt);

    expect(repository.pausedSessionId, 'session-1');
    expect(repository.pausedAt, pausedAt);
  });
}

class _FakeSessionRepository implements ISessionRepository {
  String? pausedSessionId;
  DateTime? pausedAt;

  @override
  Future<void> endSession(String sessionId, DateTime endedAt) async {}

  @override
  Future<List<SessionEntity>> getSessionsForTask(String taskId) async => <SessionEntity>[];

  @override
  Future<void> pauseSession(String sessionId, DateTime pausedAt) async {
    pausedSessionId = sessionId;
    this.pausedAt = pausedAt;
  }

  @override
  Future<void> resumeSession(String sessionId, DateTime resumedAt) async {}

  @override
  Future<void> startSession(SessionEntity session) async {}
}
