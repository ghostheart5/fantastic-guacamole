import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class UnlinkTaskFromGoalUsecase {
  const UnlinkTaskFromGoalUsecase(this._goalRepository, this._taskRepository);

  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;

  Future<TaskEntity?> call({
    required String taskId,
    required String goalId,
  }) async {
    final String targetTaskId = taskId.trim();
    final String targetGoalId = goalId.trim();

    if (targetTaskId.isEmpty || targetGoalId.isEmpty) {
      return null;
    }

    final bool goalExists = _goalRepository.getGoals().any(
      (goal) => goal.id == targetGoalId,
    );

    if (!goalExists) {
      return null;
    }

    final TaskEntity? task = await _taskRepository.getTaskById(targetTaskId);

    if (task == null || task.goalId != targetGoalId) {
      return null;
    }

    final TaskEntity updated = TaskEntity(
      id: task.id,
      title: task.title,
      kind: task.kind,
      description: task.description,
      createdAt: task.createdAt,
      isCompleted: task.isCompleted,
      priority: task.priority,
      difficulty: task.difficulty,
      energyRequired: task.energyRequired,
      estimatedDuration: task.estimatedDuration,
      completedAt: task.completedAt,
      scheduledFor: task.scheduledFor,
      dueDate: task.dueDate,
      goalId: null,
      isCanceled: task.isCanceled,
      subtasks: task.subtasks,
      recurrenceRule: task.recurrenceRule,
    );

    await _taskRepository.saveTask(updated);

    return updated;
  }
}
