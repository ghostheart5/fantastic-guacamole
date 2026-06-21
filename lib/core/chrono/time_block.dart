class TimeBlock {
  const TimeBlock({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.type,
    required this.priority,
    required this.energy,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String type; // focus, meeting, personal
  final int priority;
  final String energy; // low, medium, high

  TimeBlock copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    String? type,
    int? priority,
    String? energy,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      energy: energy ?? this.energy,
    );
  }
}
