import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/end_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EndSession delegates and awards progression XP', () async {
    final _FakeSessionRepository sessionRepository = _FakeSessionRepository();
    final _FakeProgressionRepository progressionRepository =
        _FakeProgressionRepository();
    progressionRepository.progression = const ProgressionEntity(xp: 5);

    final DateTime endedAt = DateTime.utc(2026, 7, 5, 11, 0);
    await EndSession(
      sessionRepository,
      progressionRepo: progressionRepository,
    ).call('session-1', endedAt);

    expect(sessionRepository.endedSessionId, 'session-1');
    expect(sessionRepository.endedAt, endedAt);
    expect(progressionRepository.progression?.xp, 30);
  });
}

class _FakeSessionRepository implements ISessionRepository {
  String? endedSessionId;
  DateTime? endedAt;

  @override
  Future<void> endSession(String sessionId, DateTime endedAt) async {
    endedSessionId = sessionId;
    this.endedAt = endedAt;
  }

  @override
  Future<List<SessionEntity>> getSessionsForTask(String taskId) async =>
      <SessionEntity>[];

  @override
  Future<void> pauseSession(String sessionId, DateTime pausedAt) async {}

  @override
  Future<void> resumeSession(String sessionId, DateTime resumedAt) async {}

  @override
  Future<void> startSession(SessionEntity session) async {}
}

class _FakeProgressionRepository implements IProgressionRepository {
  ProgressionEntity? progression;

  @override
  Future<ProgressionEntity?> getProgression() async => progression;

  @override
  Future<void> saveProgression(ProgressionEntity progression) async {
    this.progression = progression;
  }
}
