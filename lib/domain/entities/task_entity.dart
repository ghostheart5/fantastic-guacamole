class TaskEntity {
  final String id;
  final String title;
  final bool done;
  final int priority;
  final int durationMinutes;
  final double energyCost;

  const TaskEntity({
    required this.id,
    required this.title,
    required this.done,
    required this.priority,
    required this.durationMinutes,
    required this.energyCost,
  });

  TaskEntity copyWith({
    String? id,
    String? title,
    bool? done,
    int? priority,
    int? durationMinutes,
    double? energyCost,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
      priority: priority ?? this.priority,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      energyCost: energyCost ?? this.energyCost,
    );
  }
}
