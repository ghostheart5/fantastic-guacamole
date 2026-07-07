import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreateTask', () {
    late _FakeTaskRepository taskRepository;

    setUp(() {
      taskRepository = _FakeTaskRepository();
    });

    test('creates a valid task with required title and sends it to repository', () async {
      final TaskEntity task = TaskEntity(
        id: 'task-1',
        title: 'Ship feature',
        createdAt: DateTime.utc(2026, 7, 5),
      );

      await CreateTask(taskRepository).call(task);

      expect((await taskRepository.getAllTasks()).single.id, 'task-1');
      expect(taskRepository.saveCalls, 1);
      expect(taskRepository.lastSavedTask?.id, 'task-1');
    });

    test('throws for invalid task', () async {
      final TaskEntity invalid = TaskEntity(
        id: 'task-bad',
        title: '   ',
        createdAt: DateTime.utc(2026, 7, 5),
      );

      await expectLater(() => CreateTask(taskRepository).call(invalid), throwsException);
    });

    test('applies default priority and completion status', () async {
      final TaskEntity task = TaskEntity(
        id: 'task-defaults',
        title: 'Default fields',
        createdAt: DateTime.utc(2026, 7, 5),
      );

      await CreateTask(taskRepository).call(task);

      final TaskEntity? saved = await taskRepository.getTaskById('task-defaults');
      expect(saved?.priority, 3);
      expect(saved?.isCompleted, isFalse);
    });

    test('simplifies priority when SI decision requests simplify', () async {
      final TaskEntity task = TaskEntity(
        id: 'task-2',
        title: 'Deep architecture pass',
        createdAt: DateTime.utc(2026, 7, 5),
        priority: 5,
      );

      await CreateTask(
        taskRepository,
        generateSiDecision: _StubGenerateSiDecision(
          const SiDecisionEntity(rationale: 'Simplify', shouldSimplify: true),
        ),
      ).call(task);

      expect((await taskRepository.getTaskById('task-2'))?.priority, 1);
    });

    test('propagates repository failure safely', () async {
      final _FailingTaskRepository failingRepository = _FailingTaskRepository();
      final TaskEntity task = TaskEntity(
        id: 'task-3',
        title: 'Will fail save',
        createdAt: DateTime.utc(2026, 7, 5),
      );

      await expectLater(() => CreateTask(failingRepository).call(task), throwsA(isA<StateError>()));
    });
  });
}

class _StubGenerateSiDecision extends GenerateSiDecision {
  _StubGenerateSiDecision(this._decision) : super(_FakeTaskRepository(), _FakeSiRepository());

  final SiDecisionEntity _decision;

  @override
  Future<SiDecisionEntity> call([String input = '']) async => _decision;
}

class _FakeTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};
  int saveCalls = 0;
  TaskEntity? lastSavedTask;

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
    saveCalls += 1;
    lastSavedTask = task;
    _tasks[task.id] = task;
  }
}

class _FailingTaskRepository extends _FakeTaskRepository {
  @override
  Future<void> saveTask(TaskEntity task) async {
    throw StateError('save failed');
  }
}

class _FakeSiRepository implements ISiRepository {
  @override
  Future<SiStateEntity?> getCurrentState() async => null;

  @override
  Future<void> saveState(SiStateEntity state) async {}
}
