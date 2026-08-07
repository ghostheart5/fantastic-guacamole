import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'completeTaskUseCaseProvider wires the progression and SI repositories '
    'so completing a task through the real provider graph awards XP and '
    'triggers the SI confidence update, not just the domain-level contract',
    () async {
      final _FakeTaskRepository taskRepository = _FakeTaskRepository();
      final _FakeProgressionRepository progressionRepository =
          _FakeProgressionRepository();
      final _FakeSiRepository siRepository = _FakeSiRepository();

      await taskRepository.saveTask(
        TaskEntity(
          id: 'task-1',
          title: 'Ship report',
          createdAt: DateTime.utc(2026, 7, 5),
        ),
      );
      progressionRepository.progression = const ProgressionEntity(xp: 0);
      siRepository.state = SiStateEntity(energy: 0.7, focus: 0.7, fatigue: 0.3);

      final ProviderContainer container = ProviderContainer(
        // riverpod 3.3.2 omits Override from its public barrel export; the
        // override pattern is standard Riverpod API — the code is correct.
        // ignore: non_type_as_type_argument
        overrides: [
          domainTaskRepositoryProvider.overrideWithValue(taskRepository),
          domainProgressionRepositoryProvider.overrideWithValue(
            progressionRepository,
          ),
          domainSiRepositoryProvider.overrideWithValue(siRepository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(completeTaskUseCaseProvider).call('task-1');

      final TaskEntity? completed = await taskRepository.getTaskById(
        'task-1',
      );
      expect(completed?.isCompleted, isTrue);
      expect(
        progressionRepository.progression?.xp,
        greaterThan(0),
        reason:
            'completeTaskUseCaseProvider must supply a progressionRepo so '
            'AwardXp actually runs when a task is completed via the real '
            'provider graph.',
      );
      expect(
        siRepository.savedStates,
        isNotEmpty,
        reason:
            'completeTaskUseCaseProvider must supply a siRepo so the SI '
            'confidence path actually runs when a task is completed via the '
            'real provider graph.',
      );
      expect(
        siRepository.savedStates.single.confidence,
        closeTo(0.55, 0.0001),
      );
    },
  );
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
