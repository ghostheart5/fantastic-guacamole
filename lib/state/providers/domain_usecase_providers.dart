import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:fantastic_guacamole/domain/usecases/get_tasks.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final domainTaskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return _TaskRepositoryAdapter(ref.read(taskRepositoryProvider));
});

final domainSiRepositoryProvider = Provider<ISiRepository>((ref) {
  return _SiRepositoryAdapter(ref);
});

final getTasksUseCaseProvider = Provider<GetTasks>((ref) {
  return GetTasks(ref.read(domainTaskRepositoryProvider));
});

final generateSiDecisionUseCaseProvider = Provider<GenerateSiDecision>((ref) {
  return GenerateSiDecision(
    ref.read(domainTaskRepositoryProvider),
    ref.read(domainSiRepositoryProvider),
  );
});

final domainSiDecisionProvider = FutureProvider<Task?>((ref) async {
  final SiDecisionEntity? decision = await ref
      .read(generateSiDecisionUseCaseProvider)
      .call();
  final String? selectedTaskId = decision?.selectedTaskId;
  if (selectedTaskId == null || selectedTaskId.isEmpty) {
    return null;
  }

  final TaskEntity? task = await ref
      .read(domainTaskRepositoryProvider)
      .getTaskById(selectedTaskId);
  return task == null ? null : _taskFromEntity(task);
});

Task _taskFromEntity(TaskEntity task) {
  return Task(
    id: task.id,
    title: task.title,
    priority: task.priority,
    difficulty: task.difficulty,
    energyRequired: task.energyRequired,
  );
}

class _TaskRepositoryAdapter implements ITaskRepository {
  _TaskRepositoryAdapter(this._repository);

  final TaskRepository _repository;

  @override
  Future<List<TaskEntity>> getAllTasks() => _repository.getAllTasks();

  @override
  Future<TaskEntity?> getTaskById(String id) => _repository.getTaskById(id);

  @override
  Future<void> saveTask(TaskEntity task) => _repository.saveTask(task);

  @override
  Future<void> deleteTask(String id) => _repository.deleteTask(id);
}

class _SiRepositoryAdapter implements ISiRepository {
  _SiRepositoryAdapter(this._ref);

  final Ref _ref;

  @override
  Future<SiStateEntity?> getCurrentState() async {
    final SIState state = _ref.read(siStateProvider);
    return SiStateEntity(
      energy: state.energy,
      focus: (state.energy * (1 - state.fatigue)).clamp(0.0, 1.0),
      fatigue: state.fatigue,
    );
  }

  @override
  Future<void> saveState(SiStateEntity state) async {
    _ref
        .read(siStateProvider.notifier)
        .replaceState(energy: state.energy, fatigue: state.fatigue);
  }
}
