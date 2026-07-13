import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:fantastic_guacamole/domain/usecases/start_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartSession', () {
    late _FakeSessionRepository sessionRepository;
    late _FakeProgressionRepository progressionRepository;

    setUp(() {
      sessionRepository = _FakeSessionRepository();
      progressionRepository = _FakeProgressionRepository();
    });

    test('starts valid session and awards XP', () async {
      final SessionEntity session = SessionEntity(
        id: 'session-1',
        taskId: 'task-1',
        startedAt: DateTime.utc(2026, 7, 5),
        plannedDuration: const Duration(minutes: 20),
      );

      await StartSession(
        sessionRepository,
        progressionRepo: progressionRepository,
      ).call(session);

      expect(sessionRepository.started.single.id, 'session-1');
      expect(progressionRepository.progression?.xp, 25);
    });

    test('throws when session duration is too short', () async {
      final SessionEntity session = SessionEntity(
        id: 'session-short',
        taskId: 'task-1',
        startedAt: DateTime.utc(2026, 7, 5),
        plannedDuration: const Duration(minutes: 3),
      );

      await expectLater(
        () => StartSession(sessionRepository).call(session),
        throwsException,
      );
    });

    test('uses SI recommendation to shorten planned duration', () async {
      final SessionEntity session = SessionEntity(
        id: 'session-2',
        taskId: 'task-1',
        startedAt: DateTime.utc(2026, 7, 5),
        plannedDuration: const Duration(minutes: 30),
      );

      await StartSession(
        sessionRepository,
        generateSiDecision: _StubGenerateSiDecision(
          const SiDecisionEntity(
            rationale: 'Simplify',
            shouldSimplify: true,
            recommendedFocusMinutes: 10,
          ),
        ),
      ).call(session);

      expect(sessionRepository.started.single.plannedDuration.inMinutes, 10);
    });
  });
}

class _StubGenerateSiDecision extends GenerateSiDecision {
  _StubGenerateSiDecision(this._decision)
    : super(_FakeTaskRepository(), _FakeSiRepository());

  final SiDecisionEntity _decision;

  @override
  Future<SiDecisionEntity> call([String input = '']) async => _decision;
}

class _FakeSessionRepository implements ISessionRepository {
  final List<SessionEntity> started = <SessionEntity>[];

  @override
  Future<void> endSession(String sessionId, DateTime endedAt) async {}

  @override
  Future<List<SessionEntity>> getSessionsForTask(String taskId) async =>
      <SessionEntity>[];

  @override
  Future<void> pauseSession(String sessionId, DateTime pausedAt) async {}

  @override
  Future<void> resumeSession(String sessionId, DateTime resumedAt) async {}

  @override
  Future<void> startSession(SessionEntity session) async {
    started.add(session);
  }
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

class _FakeTaskRepository implements ITaskRepository {
  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[];

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

class _FakeSiRepository implements ISiRepository {
  @override
  Future<SiStateEntity?> getCurrentState() async => null;

  @override
  Future<void> saveState(SiStateEntity state) async {}
}
