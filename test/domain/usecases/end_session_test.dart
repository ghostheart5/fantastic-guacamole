import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/end_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EndSession', () {
    late _FakeSessionRepository sessionRepository;
    late _FakeProgressionRepository progressionRepository;

    SessionEntity openSession() => SessionEntity(
      id: 'session-1',
      taskId: 'task-1',
      startedAt: DateTime.utc(2026, 7, 5, 10, 0),
      plannedDuration: const Duration(minutes: 25),
    );

    setUp(() {
      sessionRepository = _FakeSessionRepository();
      progressionRepository = _FakeProgressionRepository();
    });

    test('ends an open session and awards session XP once', () async {
      sessionRepository.sessions['session-1'] = openSession();
      progressionRepository.progression = const ProgressionEntity(xp: 5);

      final DateTime endedAt = DateTime.utc(2026, 7, 5, 11, 0);
      await EndSession(
        sessionRepository,
        progressionRepo: progressionRepository,
      ).call('session-1', endedAt);

      expect(sessionRepository.endedSessionId, 'session-1');
      expect(sessionRepository.endedAt, endedAt);
      expect(progressionRepository.progression?.xp, 5 + ProgressionPolicy.sessionXp);
    });

    test('ending an already-ended session throws and awards no further XP', () async {
      sessionRepository.sessions['session-1'] = openSession();
      progressionRepository.progression = const ProgressionEntity();

      final EndSession endSession = EndSession(
        sessionRepository,
        progressionRepo: progressionRepository,
      );

      await endSession.call('session-1', DateTime.utc(2026, 7, 5, 11, 0));
      final int xpAfterFirstEnd = progressionRepository.progression!.xp;
      expect(xpAfterFirstEnd, ProgressionPolicy.sessionXp);

      await expectLater(
        () => endSession.call('session-1', DateTime.utc(2026, 7, 5, 12, 0)),
        throwsStateError,
      );

      // The replay must not have re-awarded XP.
      expect(progressionRepository.progression?.xp, xpAfterFirstEnd);
      expect(progressionRepository.saveCount, 1);
    });

    test('throws when the session does not exist', () async {
      await expectLater(
        () => EndSession(sessionRepository).call('missing', DateTime.utc(2026)),
        throwsStateError,
      );
    });

    test('rejects a blank session id', () async {
      await expectLater(
        () => EndSession(sessionRepository).call('   ', DateTime.utc(2026)),
        throwsArgumentError,
      );
      expect(sessionRepository.endedSessionId, isNull);
    });
  });
}

class _FakeSessionRepository implements ISessionRepository {
  final Map<String, SessionEntity> sessions = <String, SessionEntity>{};
  String? endedSessionId;
  DateTime? endedAt;

  @override
  Future<void> endSession(String sessionId, DateTime endedAt) async {
    endedSessionId = sessionId;
    this.endedAt = endedAt;
    final SessionEntity? existing = sessions[sessionId];
    if (existing != null) {
      sessions[sessionId] = SessionEntity(
        id: existing.id,
        taskId: existing.taskId,
        startedAt: existing.startedAt,
        plannedDuration: existing.plannedDuration,
        endedAt: endedAt,
      );
    }
  }

  @override
  Future<SessionEntity?> getSessionById(String sessionId) async =>
      sessions[sessionId];

  @override
  Future<List<SessionEntity>> getSessionsForTask(String taskId) async =>
      sessions.values.where((SessionEntity s) => s.taskId == taskId).toList();

  @override
  Future<void> pauseSession(String sessionId, DateTime pausedAt) async {}

  @override
  Future<void> resumeSession(String sessionId, DateTime resumedAt) async {}

  @override
  Future<void> startSession(SessionEntity session) async {
    sessions[session.id] = session;
  }
}

class _FakeProgressionRepository implements IProgressionRepository {
  ProgressionEntity? progression;
  int saveCount = 0;

  @override
  Future<ProgressionEntity?> getProgression() async => progression;

  @override
  Future<void> saveProgression(ProgressionEntity progression) async {
    saveCount++;
    this.progression = progression;
  }
}
