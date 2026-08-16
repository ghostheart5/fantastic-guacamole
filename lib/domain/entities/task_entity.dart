import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

class TaskEntity {
  const TaskEntity({
    required this.id,
    required this.title,
    this.kind,
    this.description,
    required this.createdAt,
    this.isCompleted = false,
    this.isSkipped = false,
    this.priority = 3,
    this.difficulty = 3,
    this.energyRequired = 3,
    this.estimatedDuration,
    this.completedAt,
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
  final String? kind;
  final String? description;
  final DateTime createdAt;
  final bool isCompleted;
  final bool isSkipped;
  final int priority;
  final int difficulty;
  final int energyRequired;
  final Duration? estimatedDuration;
  final DateTime? completedAt;
  final DateTime? skippedAt;
  final DateTime? scheduledFor;
  final String? occurrenceKey;
  final DateTime? dueDate;
  final String? goalId;
  final bool isCanceled;
  final List<String> subtasks;
  final RecurrenceRule recurrenceRule;

  /// Produces the one-time identity for a task's initial actionable slot.
  ///
  /// Existing records did not persist an occurrence key.  Their current due
  /// date may already have been changed by a legacy reschedule, so it is not
  /// safe to use it as a fallback.  The immutable creation identity and task
  /// ID remain stable across a restart and are therefore the compatibility
  /// fallback.  New tasks persist this value before their first transition.
  static String deriveOccurrenceKey({
    required String taskId,
    required DateTime createdAt,
  }) => 'v1:$taskId:${createdAt.toUtc().toIso8601String()}';

  TaskEntity copyWith({
    String? id,
    String? title,
    String? kind,
    String? description,
    DateTime? createdAt,
    bool? isCompleted,
    bool? isSkipped,
    int? priority,
    int? difficulty,
    int? energyRequired,
    Duration? estimatedDuration,
    DateTime? completedAt,
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
      kind: kind ?? this.kind,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isSkipped: isSkipped ?? this.isSkipped,
      priority: priority ?? this.priority,
      difficulty: difficulty ?? this.difficulty,
      energyRequired: energyRequired ?? this.energyRequired,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
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
  TaskEntity complete() =>
      copyWith(isCompleted: true, completedAt: DateTime.now());

  TaskEntity cancel() => copyWith(isCanceled: true);

  bool get isScheduled => scheduledFor != null;

  bool get isOverdue {
    if (dueDate == null) return false;
    return !isCompleted && !isSkipped && DateTime.now().isAfter(dueDate!);
  }

  bool get hasSubtasks => subtasks.isNotEmpty;

  TaskEntity addSubtask(String id) => copyWith(subtasks: [...subtasks, id]);

  TaskEntity removeSubtask(String id) =>
      copyWith(subtasks: subtasks.where((t) => t != id).toList());

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
