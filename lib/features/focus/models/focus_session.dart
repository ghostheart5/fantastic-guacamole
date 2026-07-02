class FocusSession {
  const FocusSession({
    required this.id,
    required this.durationSeconds,
    required this.startedAt,
    this.completedAt,
    this.completed = false,
    this.skipped = false,
  });

  final String id;
  final int durationSeconds;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool completed;
  final bool skipped;

  FocusSession copyWith({
    String? id,
    int? durationSeconds,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? completed,
    bool? skipped,
  }) {
    return FocusSession(
      id: id ?? this.id,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      completed: completed ?? this.completed,
      skipped: skipped ?? this.skipped,
    );
  }
}
