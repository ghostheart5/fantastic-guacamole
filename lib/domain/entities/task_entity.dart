class TaskEntity {
  const TaskEntity({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.isCompleted = false,
    this.priority = 3,
    this.difficulty = 3,
    this.energyRequired = 3,
    this.estimatedDuration,
    this.completedAt,
    this.scheduledFor,
    this.dueDate,
    this.goalId,
    this.isCanceled = false,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final bool isCompleted;
  final int priority;
  final int difficulty;
  final int energyRequired;
  final Duration? estimatedDuration;
  final DateTime? completedAt;
  final DateTime? scheduledFor;
  final DateTime? dueDate;
  final String? goalId;
  final bool isCanceled;

  TaskEntity copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    bool? isCompleted,
    int? priority,
    int? difficulty,
    int? energyRequired,
    Duration? estimatedDuration,
    DateTime? completedAt,
    DateTime? scheduledFor,
    DateTime? dueDate,
    String? goalId,
    bool? isCanceled,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      difficulty: difficulty ?? this.difficulty,
      energyRequired: energyRequired ?? this.energyRequired,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      completedAt: completedAt ?? this.completedAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      dueDate: dueDate ?? this.dueDate,
      goalId: goalId ?? this.goalId,
      isCanceled: isCanceled ?? this.isCanceled,
    );
  }
}
