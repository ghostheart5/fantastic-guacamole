import '../../../core/utils/validators.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/repositories/mission_repository.dart';
import '../../../data/repositories/mission_repository_impl.dart';
import '../../../domain/entities/mission.dart';
import '../../../domain/entities/task_entity.dart';
import '../../../domain/usecases/chronocreator/create_mission_usecase.dart';
import '../../../domain/usecases/chronocreator/toggle_task_completion_usecase.dart';

class CreatorController {
  CreatorController({MissionRepository? repository})
    : _repository = repository ?? MissionRepositoryImpl(),
      _createMissionUseCase = CreateMissionUseCase(),
      _toggleTaskCompletionUseCase = ToggleTaskCompletionUseCase();

  final MissionRepository _repository;
  final CreateMissionUseCase _createMissionUseCase;
  final ToggleTaskCompletionUseCase _toggleTaskCompletionUseCase;

  Future<List<MissionModel>> loadMissions() => _repository.loadMissions();

  Future<void> saveMissions(List<MissionModel> missions) {
    return _repository.saveMissions(missions);
  }

  MissionModel createMission(String name) {
    final Mission mission = _createMissionUseCase(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );

    return MissionModel(
      id: mission.id,
      name: mission.name,
      tasks: const <TaskModel>[],
    );
  }

  MissionModel addTask(MissionModel mission, String title) {
    if (!Validators.isNonEmpty(title)) {
      return mission;
    }

    final TaskModel task = TaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
    );

    return mission.copyWith(tasks: <TaskModel>[...mission.tasks, task]);
  }

  MissionModel toggleTask(MissionModel mission, String taskId) {
    final List<TaskModel> updated = mission.tasks.map((TaskModel task) {
      if (task.id != taskId) {
        return task;
      }

      final TaskEntity domainTask = TaskEntity(
        id: task.id,
        title: task.title,
        done: task.done,
        priority: 1,
        durationMinutes: 30,
        energyCost: 0.5,
      );
      final TaskEntity toggled = _toggleTaskCompletionUseCase(domainTask);
      return task.copyWith(done: toggled.done);
    }).toList();
    return mission.copyWith(tasks: updated);
  }

  MissionModel removeTask(MissionModel mission, String taskId) {
    return mission.copyWith(
      tasks: mission.tasks
          .where((TaskModel task) => task.id != taskId)
          .toList(),
    );
  }

  Future<void> recordCompletion({
    required String missionName,
    required String taskTitle,
  }) {
    return _repository.addCompletedTaskLog('$missionName: $taskTitle');
  }
}
