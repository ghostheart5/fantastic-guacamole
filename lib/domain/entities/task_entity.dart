import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Canonical task type used by repositories and use cases.
class TaskEntity {
  const TaskEntity({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.isCompleted = false,
    this.priority = 3,
    this.difficulty = 3,
    this.energyRequired = 3,
    this.estimatedDuration,
    this.completedAt,
    this.isSkipped = false,
    this.skippedAt,
    this.scheduledFor,
    this.occurrenceKey,
    this.dueDate,
    this.goalId,
    this.isCanceled = false,
    this.subtasks = const [],
    this.recurrenceRule = RecurrenceRule.none,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isCompleted;
  final int priority;
  final int difficulty;
  final int energyRequired;
  final Duration? estimatedDuration;
  final DateTime? completedAt;
  final bool isSkipped;
  final DateTime? skippedAt;
  final DateTime? scheduledFor;
  final String? occurrenceKey;
  final DateTime? dueDate;
  final String? goalId;
  final bool isCanceled;
  final List<String> subtasks;
  final RecurrenceRule recurrenceRule;

  static String deriveOccurrenceKey({
    required String taskId,
    required DateTime createdAt,
  }) => 'v1:$taskId:${createdAt.toUtc().toIso8601String()}';

  TaskEntity copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
    int? priority,
    int? difficulty,
    int? energyRequired,
    Duration? estimatedDuration,
    DateTime? completedAt,
    bool? isSkipped,
    DateTime? skippedAt,
    bool clearCompletedAt = false,
    bool clearSkippedAt = false,
    DateTime? scheduledFor,
    String? occurrenceKey,
    DateTime? dueDate,
    String? goalId,
    bool? isCanceled,
    List<String>? subtasks,
    RecurrenceRule? recurrenceRule,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      difficulty: difficulty ?? this.difficulty,
      energyRequired: energyRequired ?? this.energyRequired,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      isSkipped: isSkipped ?? this.isSkipped,
      skippedAt: clearSkippedAt ? null : skippedAt ?? this.skippedAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      occurrenceKey: occurrenceKey ?? this.occurrenceKey,
      dueDate: dueDate ?? this.dueDate,
      goalId: goalId ?? this.goalId,
      isCanceled: isCanceled ?? this.isCanceled,
      subtasks: subtasks ?? this.subtasks,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    );
  }

  // Domain behavior
  TaskEntity complete() {
    final DateTime now = DateTime.now();
    return copyWith(isCompleted: true, completedAt: now, updatedAt: now);
  }

  TaskEntity cancel() => copyWith(isCanceled: true, updatedAt: DateTime.now());

  bool get isScheduled => scheduledFor != null;

  bool get isOverdue {
    if (dueDate == null) return false;
    return !isCompleted && !isSkipped && DateTime.now().isAfter(dueDate!);
  }

  bool get hasSubtasks => subtasks.isNotEmpty;

  TaskEntity addSubtask(String id) =>
      copyWith(subtasks: [...subtasks, id], updatedAt: DateTime.now());

  TaskEntity removeSubtask(String id) => copyWith(
    subtasks: subtasks.where((t) => t != id).toList(),
    updatedAt: DateTime.now(),
  );

  bool get isHighPriority => priority >= 4;
  bool get isLowPriority => priority <= 2;

  bool get isHighDifficulty => difficulty >= 4;
  bool get isLowDifficulty => difficulty <= 2;

  bool get isHighEnergy => energyRequired >= 4;
  bool get isLowEnergy => energyRequired <= 2;

  bool get hasEstimate => estimatedDuration != null;

  Duration get estimateOrDefault =>
      estimatedDuration ?? const Duration(minutes: 25);

  bool get isRecurring => recurrenceRule != RecurrenceRule.none;

  void validate() {
    if (isCompleted && completedAt == null) {
      throw StateError('Completed tasks must have a completedAt timestamp');
    }
    if (isSkipped && skippedAt == null) {
      throw StateError('Skipped tasks must have a skippedAt timestamp');
    }
  }
}
