import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenerateSiDecision', () {
    late _FakeTaskRepository taskRepository;
    late _FakeSiRepository siRepository;

    setUp(() {
      taskRepository = _FakeTaskRepository();
      siRepository = _FakeSiRepository();
    });

    test('returns no-state rationale when SI state is missing', () async {
      final decision = await GenerateSiDecision(taskRepository, siRepository).call();

      expect(decision.rationale, 'No state available.');
      expect(decision.selectedTaskId, isNull);
    });

    test('suggests break when fatigue high or energy low', () async {
      siRepository.state = SiStateEntity(energy: 0.2, focus: 0.5, fatigue: 0.8);

      final decision = await GenerateSiDecision(taskRepository, siRepository).call();

      expect(decision.shouldTakeBreak, isTrue);
      expect(decision.rationale, contains('take a break'));
    });

    test('returns no tasks rationale when task list empty', () async {
      siRepository.state = SiStateEntity(energy: 0.8, focus: 0.8, fatigue: 0.2);

      final decision = await GenerateSiDecision(taskRepository, siRepository).call();

      expect(decision.rationale, 'No tasks available.');
    });

    test('selects highest priority task and orders task IDs descending', () async {
      siRepository.state = SiStateEntity(energy: 0.8, focus: 0.8, fatigue: 0.2);
      await taskRepository.saveTask(
        TaskEntity(id: 'low', title: 'Low', createdAt: DateTime.utc(2026, 7, 5), priority: 1),
      );
      await taskRepository.saveTask(
        TaskEntity(id: 'high', title: 'High', createdAt: DateTime.utc(2026, 7, 5), priority: 5),
      );

      final decision = await GenerateSiDecision(taskRepository, siRepository).call();

      expect(decision.selectedTaskId, 'high');
      expect(decision.orderedTaskIds, <String>['high', 'low']);
      expect(decision.action, 'Focus on: High');
      expect(decision.recommendedFocusMinutes, 25);
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

class _FakeSiRepository implements ISiRepository {
  SiStateEntity? state;

  @override
  Future<SiStateEntity?> getCurrentState() async => state;

  @override
  Future<void> saveState(SiStateEntity state) async {
    this.state = state;
  }
}
