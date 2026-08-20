import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

/// Shared, non-persistent projection of task truth required by planning.
class PlannerInput {
  const PlannerInput({
    required this.id,
    required this.title,
    required this.priority,
    required this.difficulty,
    required this.energyRequired,
    required this.isCompleted,
    required this.isCanceled,
    required this.prerequisiteIds,
    required this.recurrenceRule,
    this.estimatedDuration,
    this.scheduledFor,
    this.dueDate,
    this.goalId,
  });

  final String id;
  final String title;
  final int priority;
  final int difficulty;
  final int energyRequired;
  final bool isCompleted;
  final bool isCanceled;
  final List<String> prerequisiteIds;
  final RecurrenceRule recurrenceRule;
  final Duration? estimatedDuration;
  final DateTime? scheduledFor;
  final DateTime? dueDate;
  final String? goalId;

  Duration get estimateOrDefault =>
      estimatedDuration ?? const Duration(minutes: 25);

  void validate() {
    if (id.trim().isEmpty || title.trim().isEmpty) {
      throw StateError('Planner input requires an id and title.');
    }
    if (priority < 1 ||
        priority > 5 ||
        difficulty < 1 ||
        difficulty > 5 ||
        energyRequired < 1 ||
        energyRequired > 5) {
      throw StateError(
        'Planner input priority, difficulty, and energy must be 1-5.',
      );
    }
    if (estimatedDuration != null && estimatedDuration! <= Duration.zero) {
      throw StateError('Planner input estimate must be positive.');
    }
  }

  /// Temporary bridge for the existing TaskRanker algorithm.
  TaskEntity toTaskEntity() => TaskEntity(
    id: id,
    title: title,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    isCompleted: isCompleted,
    completedAt: isCompleted ? DateTime.fromMillisecondsSinceEpoch(0) : null,
    priority: priority,
    difficulty: difficulty,
    energyRequired: energyRequired,
    estimatedDuration: estimatedDuration,
    scheduledFor: scheduledFor,
    dueDate: dueDate,
    goalId: goalId,
    isCanceled: isCanceled,
    subtasks: prerequisiteIds,
    recurrenceRule: recurrenceRule,
  );
}

/// The sole conversion boundary for persisted and legacy task read models.
class PlannerInputAdapter {
  const PlannerInputAdapter._();

  static PlannerInput fromTaskEntity(TaskEntity task) => PlannerInput(
    id: task.id,
    title: task.title,
    priority: task.priority,
    difficulty: task.difficulty,
    energyRequired: task.energyRequired,
    isCompleted: task.isCompleted,
    isCanceled: task.isCanceled,
    prerequisiteIds: List<String>.unmodifiable(task.subtasks),
    recurrenceRule: task.recurrenceRule,
    estimatedDuration: task.estimatedDuration,
    scheduledFor: task.scheduledFor,
    dueDate: task.dueDate,
    goalId: task.goalId,
  );

  static PlannerInput fromLegacyTask(Task task) => PlannerInput(
    id: task.id,
    title: task.title,
    priority: task.priority,
    difficulty: task.difficulty,
    energyRequired: task.energyRequired,
    isCompleted: task.isCompleted,
    isCanceled: task.isCanceled,
    prerequisiteIds: List<String>.unmodifiable(task.subtasks),
    recurrenceRule: task.recurrenceRule,
    scheduledFor: task.scheduledFor,
    dueDate: task.dueDate,
    goalId: task.goalId,
    estimatedDuration: task.estimatedDuration,
  );

  static List<PlannerInput> fromTaskEntities(List<TaskEntity> tasks) =>
      tasks.map(fromTaskEntity).toList(growable: false);

  static List<PlannerInput> fromLegacyTasks(List<Task> tasks) =>
      tasks.map(fromLegacyTask).toList(growable: false);

  static Task toLegacyTask(PlannerInput input) => Task(
    id: input.id,
    title: input.title,
    priority: input.priority,
    difficulty: input.difficulty,
    energyRequired: input.energyRequired,
    scheduledFor: input.scheduledFor,
    dueDate: input.dueDate,
    goalId: input.goalId,
    estimatedDuration: input.estimatedDuration ?? const Duration(minutes: 30),
    isCompleted: input.isCompleted,
    isCanceled: input.isCanceled,
    subtasks: input.prerequisiteIds,
    recurrenceRule: input.recurrenceRule,
  );

  static List<Task> toLegacyTasks(List<PlannerInput> inputs) =>
      inputs.map(toLegacyTask).toList(growable: false);
}
