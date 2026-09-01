// CHRONOSPARK-CLASS: DEPRECATED | Feature: Task compatibility
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

/// Compatibility constructor for older UI and engine call sites.
///
/// All state and behavior live in [TaskEntity]. This subclass only preserves
/// the historical constructor and non-null duration contract while callers
/// migrate to the canonical type.
@Deprecated('Use TaskEntity. This compatibility type stores no extra state.')
class Task extends TaskEntity {
  // Keep the legacy non-null duration contract while the canonical base is nullable.
  // ignore: use_super_parameters
  Task({
    required String id,
    required String title,
    required int priority,
    required int difficulty,
    required int energyRequired,
    DateTime? scheduledFor,
    DateTime? dueDate,
    Duration estimatedDuration = const Duration(minutes: 30),
    bool isCompleted = false,
    bool isCanceled = false,
    DateTime? completedAt,
    String? goalId,
    List<String> subtasks = const <String>[],
    RecurrenceRule recurrenceRule = RecurrenceRule.none,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isSkipped = false,
    DateTime? skippedAt,
    String? occurrenceKey,
  }) : super(
         id: id,
         title: title,
         description: description,
         createdAt: createdAt,
         updatedAt: updatedAt,
         isCompleted: isCompleted,
         priority: priority,
         difficulty: difficulty,
         energyRequired: energyRequired,
         estimatedDuration: estimatedDuration,
         completedAt: completedAt,
         isSkipped: isSkipped,
         skippedAt: skippedAt,
         scheduledFor: scheduledFor,
         occurrenceKey: occurrenceKey,
         dueDate: dueDate,
         goalId: goalId,
         isCanceled: isCanceled,
         subtasks: subtasks,
         recurrenceRule: recurrenceRule,
       );

  @override
  Duration get estimatedDuration => super.estimatedDuration!;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task.fromEntity(TaskEntity.fromJson(json));
  }

  factory Task.fromEntity(TaskEntity entity) => Task(
    id: entity.id,
    title: entity.title,
    description: entity.description,
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
    priority: entity.priority,
    difficulty: entity.difficulty,
    energyRequired: entity.energyRequired,
    scheduledFor: entity.scheduledFor,
    dueDate: entity.dueDate,
    estimatedDuration: entity.estimateOrDefault,
    isCompleted: entity.isCompleted,
    isSkipped: entity.isSkipped,
    isCanceled: entity.isCanceled,
    completedAt: entity.completedAt,
    skippedAt: entity.skippedAt,
    occurrenceKey: entity.occurrenceKey,
    goalId: entity.goalId,
    subtasks: entity.subtasks,
    recurrenceRule: entity.recurrenceRule,
  );

  @override
  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool clearDescription = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
    int? priority,
    int? difficulty,
    int? energyRequired,
    Duration? estimatedDuration,
    bool clearEstimatedDuration = false,
    DateTime? completedAt,
    bool? isSkipped,
    DateTime? skippedAt,
    bool clearCompletedAt = false,
    bool clearSkippedAt = false,
    DateTime? scheduledFor,
    bool clearScheduledFor = false,
    String? occurrenceKey,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? goalId,
    bool clearGoalId = false,
    bool? isCanceled,
    List<String>? subtasks,
    RecurrenceRule? recurrenceRule,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: clearDescription ? null : description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priority: priority ?? this.priority,
      difficulty: difficulty ?? this.difficulty,
      energyRequired: energyRequired ?? this.energyRequired,
      scheduledFor: clearScheduledFor
          ? null
          : scheduledFor ?? this.scheduledFor,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      estimatedDuration: clearEstimatedDuration
          ? const Duration(minutes: 30)
          : estimatedDuration ?? this.estimatedDuration,
      isCompleted: isCompleted ?? this.isCompleted,
      isSkipped: isSkipped ?? this.isSkipped,
      isCanceled: isCanceled ?? this.isCanceled,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      skippedAt: clearSkippedAt ? null : skippedAt ?? this.skippedAt,
      occurrenceKey: occurrenceKey ?? this.occurrenceKey,
      goalId: clearGoalId ? null : goalId ?? this.goalId,
      subtasks: subtasks ?? this.subtasks,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    );
  }
}
