import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/resume_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ResumeSession delegates to repository', () async {
    final _FakeSessionRepository repository = _FakeSessionRepository();
    final DateTime resumedAt = DateTime.utc(2026, 7, 5, 10, 45);

    await ResumeSession(repository).call('session-1', resumedAt);

    expect(repository.resumedSessionId, 'session-1');
    expect(repository.resumedAt, resumedAt);
  });
}

class _FakeSessionRepository implements ISessionRepository {
  String? resumedSessionId;
  DateTime? resumedAt;

  @override
  Future<void> endSession(String sessionId, DateTime endedAt) async {}

  @override
  Future<List<SessionEntity>> getSessionsForTask(String taskId) async =>
      <SessionEntity>[];

  @override
  Future<void> pauseSession(String sessionId, DateTime pausedAt) async {}

  @override
  Future<void> resumeSession(String sessionId, DateTime resumedAt) async {
    resumedSessionId = sessionId;
    this.resumedAt = resumedAt;
  }

  @override
  Future<void> startSession(SessionEntity session) async {}
}
