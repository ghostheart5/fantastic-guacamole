import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/si_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every unsafe term in SiPolicy's blocklist.
const List<String> _unsafePhrases = <String>[
  'guarantee',
  'cure',
  'diagnose',
  'prescribe',
  'legal advice',
];

void main() {
  group('SiPolicy.sanitize is a terminal gate', () {
    for (final String phrase in _unsafePhrases) {
      test('withholds a decision whose rationale contains "$phrase"', () {
        final SiDecisionEntity decision = SiDecisionEntity(
          rationale: 'This will $phrase your attention problem.',
        );

        final SiDecisionEntity gated = SiPolicy.sanitize(decision);

        expect(gated.rationale, SiPolicy.withheldRationale);
        expect(SiPolicy.isSupportedAndSafe(gated), isTrue);
      });

      test('withholds a decision whose action contains "$phrase"', () {
        final SiDecisionEntity decision = SiDecisionEntity(
          rationale: 'Fine',
          action: 'I will $phrase this for you.',
        );

        final SiDecisionEntity gated = SiPolicy.sanitize(decision);

        expect(gated.action, isEmpty);
        expect(SiPolicy.isSupportedAndSafe(gated), isTrue);
      });

      test('withholds a decision whose reasoningTrace contains "$phrase"', () {
        final SiDecisionEntity decision = SiDecisionEntity(
          rationale: 'Fine',
          reasoningTrace: 'Internally I would $phrase.',
        );

        final SiDecisionEntity gated = SiPolicy.sanitize(decision);

        expect(gated.reasoningTrace, isEmpty);
        expect(SiPolicy.isSupportedAndSafe(gated), isTrue);
      });
    }

    test('is case-insensitive', () {
      final SiDecisionEntity gated = SiPolicy.sanitize(
        const SiDecisionEntity(rationale: 'I GUARANTEE results.'),
      );

      expect(gated.rationale, SiPolicy.withheldRationale);
    });

    test('the withheld fallback is itself safe', () {
      expect(
        SiPolicy.isSupportedAndSafe(
          const SiDecisionEntity(rationale: SiPolicy.withheldRationale),
        ),
        isTrue,
      );
    });

    test('passes a safe decision through unchanged', () {
      const SiDecisionEntity decision = SiDecisionEntity(
        selectedTaskId: 'task-1',
        rationale: 'Highest priority task selected.',
        action: 'Work on: Write the spec',
      );

      final SiDecisionEntity gated = SiPolicy.sanitize(decision);

      expect(gated.selectedTaskId, 'task-1');
      expect(gated.action, 'Work on: Write the spec');
      expect(gated.rationale, 'Highest priority task selected.');
    });

    test('still applies enforce() to a safe decision', () {
      const SiDecisionEntity decision = SiDecisionEntity(
        rationale: 'Simplify',
        shouldSimplify: true,
        recommendedExecutionMinutes: 45,
      );

      final SiDecisionEntity gated = SiPolicy.sanitize(decision);

      expect(gated.recommendedExecutionMinutes, 15);
      expect(gated.tone, 'calm');
    });
  });

  group('GenerateSiDecision gates its output', () {
    test('an unsafe task title cannot escape the use case', () async {
      final _FakeTaskRepository taskRepo = _FakeTaskRepository(<TaskEntity>[
        TaskEntity(
          id: 'task-1',
          title: 'I guarantee this cures burnout',
          createdAt: DateTime.utc(2026, 7, 4),
          priority: 5,
        ),
      ]);
      final _FakeSiRepository siRepo = _FakeSiRepository(
        SiStateEntity(energy: 0.8, attention: 0.7, fatigue: 0.2),
      );

      final SiDecisionEntity decision = await GenerateSiDecision(
        taskRepo,
        siRepo,
      ).call();

      expect(SiPolicy.isSupportedAndSafe(decision), isTrue);
      expect(decision.rationale, SiPolicy.withheldRationale);
      expect(decision.action, isEmpty);
    });

    test('a safe task still produces a normal recommendation', () async {
      final _FakeTaskRepository taskRepo = _FakeTaskRepository(<TaskEntity>[
        TaskEntity(
          id: 'task-1',
          title: 'Write the spec',
          createdAt: DateTime.utc(2026, 7, 4),
          priority: 5,
        ),
      ]);
      final _FakeSiRepository siRepo = _FakeSiRepository(
        SiStateEntity(energy: 0.8, attention: 0.7, fatigue: 0.2),
      );

      final SiDecisionEntity decision = await GenerateSiDecision(
        taskRepo,
        siRepo,
      ).call();

      expect(decision.selectedTaskId, 'task-1');
      expect(decision.action, 'Work on: Write the spec');
    });

    test('missing required context yields the no-state decision', () async {
      final _FakeTaskRepository taskRepo = _FakeTaskRepository(
        const <TaskEntity>[],
      );
      final _FakeSiRepository siRepo = _FakeSiRepository(null);

      final SiDecisionEntity decision = await GenerateSiDecision(
        taskRepo,
        siRepo,
      ).call();

      expect(decision.rationale, 'No state available.');
      expect(decision.selectedTaskId, isNull);
    });

    test('context flags gate generation before any task is read', () async {
      final _FakeTaskRepository taskRepo = _FakeTaskRepository(<TaskEntity>[
        TaskEntity(
          id: 'task-1',
          title: 'Write the spec',
          createdAt: DateTime.utc(2026, 7, 4),
          priority: 5,
        ),
      ]);
      final _FakeSiRepository siRepo = _FakeSiRepository(
        SiStateEntity(energy: 0.8, attention: 0.7, fatigue: 0.2),
      );

      final SiDecisionEntity decision = await GenerateSiDecision(
        taskRepo,
        siRepo,
        withinSubscriptionLimits: false,
      ).call();

      expect(decision.selectedTaskId, isNull);
      expect(
        taskRepo.getAllTasksCallCount,
        0,
        reason: 'context gate must short-circuit before reading tasks',
      );
    });
  });
}

class _FakeTaskRepository implements ITaskRepository {
  _FakeTaskRepository(this._tasks);

  final List<TaskEntity> _tasks;
  int getAllTasksCallCount = 0;

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    getAllTasksCallCount++;
    return _tasks;
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    for (final TaskEntity task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

class _FakeSiRepository implements ISiRepository {
  _FakeSiRepository(this._state);

  final SiStateEntity? _state;

  @override
  Future<SiStateEntity?> getCurrentState() async => _state;

  @override
  Future<void> saveState(SiStateEntity state) async {}
}
