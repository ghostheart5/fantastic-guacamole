import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/skip_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SkipTask', () {
    late _FakeTaskRepository taskRepository;
    late _FakeLearningRepository learningRepository;
    late _FakeSiRepository siRepository;

    setUp(() {
      taskRepository = _FakeTaskRepository();
      learningRepository = _FakeLearningRepository();
      siRepository = _FakeSiRepository();
      siRepository.state = SiStateEntity(energy: 0.6, focus: 0.6, fatigue: 0.4);
    });

    test(
      'marks task skipped, feeds learning signal, and updates SI state',
      () async {
        await taskRepository.saveTask(
          TaskEntity(
            id: 'task-1',
            title: 'Skip me',
            createdAt: DateTime.utc(2026, 7, 5),
          ),
        );

        final LearningEntity result = await SkipTask(
          taskRepository,
          learningRepository,
          siRepo: siRepository,
        ).call(taskId: 'task-1', difficulty: 4);

        expect(result.skipped, 1);
        expect(result.completed, 0);
        expect(learningRepository.state?.skipped, 1);
        expect(learningRepository.saveCalls, 1);
        expect(siRepository.state?.anticipatesConfusion, isTrue);
        expect(siRepository.state?.confidence, closeTo(0.43, 0.0001));
        expect(siRepository.saveCalls, 1);
      },
    );

    test('does not erase task data when skipped', () async {
      await taskRepository.saveTask(
        TaskEntity(
          id: 'task-keep',
          title: 'Keep data',
          description: 'Should remain unchanged',
          createdAt: DateTime.utc(2026, 7, 5),
          priority: 5,
        ),
      );

      await SkipTask(
        taskRepository,
        learningRepository,
        siRepo: siRepository,
      ).call(taskId: 'task-keep', difficulty: 2);

      final TaskEntity? taskAfterSkip = await taskRepository.getTaskById(
        'task-keep',
      );
      expect(taskAfterSkip, isNotNull);
      expect(taskAfterSkip?.title, 'Keep data');
      expect(taskAfterSkip?.description, 'Should remain unchanged');
      expect(taskAfterSkip?.priority, 5);
      expect(taskAfterSkip?.isCompleted, isFalse);
    });

    test('throws when task missing', () async {
      await expectLater(
        () => SkipTask(
          taskRepository,
          learningRepository,
        ).call(taskId: 'missing', difficulty: 3),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};

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
    _tasks[task.id] = task;
  }
}

class _FakeLearningRepository implements ILearningRepository {
  LearningEntity? state;
  int saveCalls = 0;

  @override
  Future<LearningEntity?> getState() async => state;

  @override
  Future<void> saveState(LearningEntity state) async {
    saveCalls += 1;
    this.state = state;
  }
}

class _FakeSiRepository implements ISiRepository {
  SiStateEntity? state;
  int saveCalls = 0;

  @override
  Future<SiStateEntity?> getCurrentState() async => state;

  @override
  Future<void> saveState(SiStateEntity state) async {
    saveCalls += 1;
    this.state = state;
  }
}
