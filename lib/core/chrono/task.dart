class Task {
  const Task({
    required this.id,
    required this.title,
    this.dueDate,
    this.completed = false,
    this.timeBlockId,
  });

  final String id;
  final String title;
  final DateTime? dueDate;
  final bool completed;
  final String? timeBlockId;

  Task copyWith({
    String? id,
    String? title,
    DateTime? dueDate,
    bool? completed,
    String? timeBlockId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      timeBlockId: timeBlockId ?? this.timeBlockId,
    );
  }
}
