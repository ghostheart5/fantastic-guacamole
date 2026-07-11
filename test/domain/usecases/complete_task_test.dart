import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompleteTask', () {
    late _FakeTaskRepository taskRepository;
    late _FakeProgressionRepository progressionRepository;
    late _FakeSiRepository siRepository;

    setUp(() {
      taskRepository = _FakeTaskRepository();
      progressionRepository = _FakeProgressionRepository();
      siRepository = _FakeSiRepository();
    });

    test(
      'completes incomplete task and triggers progression + SI path',
      () async {
        await taskRepository.saveTask(
          TaskEntity(
            id: 'task-1',
            title: 'Complete report',
            createdAt: DateTime.utc(2026, 7, 5),
          ),
        );
        progressionRepository.progression = const ProgressionEntity(xp: 0);
        siRepository.state = SiStateEntity(
          energy: 0.7,
          focus: 0.7,
          fatigue: 0.3,
        );

        await CompleteTask(
          taskRepository,
          progressionRepo: progressionRepository,
          siRepo: siRepository,
        ).call('task-1');

        final TaskEntity? completed = await taskRepository.getTaskById(
          'task-1',
        );
        expect(completed?.isCompleted, isTrue);
        expect(completed?.completedAt, isNotNull);
        expect(progressionRepository.progression?.xp, 10);
        expect(
          siRepository.savedStates.single.confidence,
          closeTo(0.55, 0.0001),
        );
      },
    );

    test('creates next recurring occurrence', () async {
      await taskRepository.saveTask(
        TaskEntity(
          id: 'task-recur',
          title: 'Daily sync',
          createdAt: DateTime.utc(2026, 7, 5),
          recurrenceRule: RecurrenceRule.daily,
        ),
      );

      await CompleteTask(taskRepository).call('task-recur');

      final List<TaskEntity> tasks = await taskRepository.getAllTasks();
      expect(tasks, hasLength(2));
      expect(
        tasks.where((TaskEntity t) => t.id != 'task-recur').single.isCompleted,
        isFalse,
      );
    });

    test('handles missing task ID', () async {
      await expectLater(
        () => CompleteTask(taskRepository).call('missing'),
        throwsA(isA<StateError>()),
      );
    });

    test('does not double-complete already completed task', () async {
      await taskRepository.saveTask(
        TaskEntity(
          id: 'done',
          title: 'Done already',
          createdAt: DateTime.utc(2026, 7, 5),
          isCompleted: true,
        ),
      );

      await expectLater(
        () => CompleteTask(taskRepository).call('done'),
        throwsA(isA<StateError>()),
      );
      expect(taskRepository.saveCalls, 1);
    });

    test('returns repository failure safely', () async {
      taskRepository.failOnSave = true;
      taskRepository.failWith = StateError('repository write failed');

      taskRepository.failOnSave = false;
      await taskRepository.saveTask(
        TaskEntity(
          id: 'task-fail-save',
          title: 'Explode on complete',
          createdAt: DateTime.utc(2026, 7, 5),
        ),
      );
      taskRepository.failOnSave = true;

      await expectLater(
        () => CompleteTask(taskRepository).call('task-fail-save'),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};
  int saveCalls = 0;
  bool failOnSave = false;
  Object failWith = StateError('save failed');

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async => _tasks.values.toList();

  @override
  Future<TaskEntity?> getTaskById(String id) async => _tasks[id];

  @override
  Future<void> saveTask(TaskEntity task) async {
    if (failOnSave) {
      throw failWith;
    }
    saveCalls += 1;
    _tasks[task.id] = task;
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

class _FakeSiRepository implements ISiRepository {
  SiStateEntity? state;
  final List<SiStateEntity> savedStates = <SiStateEntity>[];

  @override
  Future<SiStateEntity?> getCurrentState() async => state;

  @override
  Future<void> saveState(SiStateEntity state) async {
    this.state = state;
    savedStates.add(state);
  }
}
