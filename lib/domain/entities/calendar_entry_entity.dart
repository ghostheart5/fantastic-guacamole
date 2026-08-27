/// CHRONOSPARK-CLASS: PLANNED | Feature: Calendar/timeline
///
/// Persisted calendar type; the UI renders TimeBlock today.
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

  bool get completed => isCompleted;

  bool validate() => end.isAfter(start) && title.trim().isNotEmpty;

  CalendarEntryEntity markComplete() => copyWith(isCompleted: true);

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

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'taskId': taskId,
    'isCompleted': isCompleted,
    'completed': isCompleted,
  };

  factory CalendarEntryEntity.fromJson(Map<String, dynamic> json) {
    final DateTime start =
        DateTime.tryParse(json['start']?.toString() ?? '') ?? DateTime.now();
    return CalendarEntryEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      description: json['description']?.toString(),
      start: start,
      end:
          DateTime.tryParse(json['end']?.toString() ?? '') ??
          start.add(const Duration(minutes: 30)),
      taskId: json['taskId']?.toString(),
      isCompleted:
          json['isCompleted'] as bool? ?? json['completed'] as bool? ?? false,
    );
  }
}
