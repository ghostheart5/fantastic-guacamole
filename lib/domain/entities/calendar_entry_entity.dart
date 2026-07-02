class CalendarEntryEntity {
  const CalendarEntryEntity({
    required this.id,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.taskId,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String? taskId;
  final bool isCompleted;

  Duration get duration => end.difference(start);

  CalendarEntryEntity copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    String? taskId,
    bool? isCompleted,
  }) {
    return CalendarEntryEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      start: start ?? this.start,
      end: end ?? this.end,
      taskId: taskId ?? this.taskId,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
