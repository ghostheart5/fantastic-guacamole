class TimeBlock {
  const TimeBlock({
    required this.id,
    required this.taskId,
    required this.title,
    required this.start,
    required this.end,
    this.completed = false,
  });

  final String id;
  final String taskId;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool completed;

  TimeBlock copyWith({
    String? id,
    String? taskId,
    String? title,
    DateTime? start,
    DateTime? end,
    bool? completed,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      completed: completed ?? this.completed,
    );
  }
}
