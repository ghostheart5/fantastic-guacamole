class SessionEntity {
  const SessionEntity({
    required this.id,
    required this.taskId,
    required this.startedAt,
    this.endedAt,
    required this.plannedDuration,
  });

  final String id;
  final String taskId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration plannedDuration;

  Duration get actualDuration {
    final end = endedAt;
    return end == null ? Duration.zero : end.difference(startedAt);
  }

  bool get isCompleted => endedAt != null;

  Duration get remaining {
    if (endedAt != null) return Duration.zero;
    final elapsed = DateTime.now().difference(startedAt);
    final left = plannedDuration - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  double get progress {
    final elapsed = actualDuration;
    if (plannedDuration.inSeconds == 0) return 1.0;
    final ratio = elapsed.inSeconds / plannedDuration.inSeconds;
    return ratio.clamp(0.0, 1.0);
  }

  bool get isOverdue {
    if (endedAt == null) return false;
    return actualDuration > plannedDuration;
  }

  SessionEntity end() {
    return SessionEntity(
      id: id,
      taskId: taskId,
      startedAt: startedAt,
      endedAt: DateTime.now(),
      plannedDuration: plannedDuration,
    );
  }

  void validate() {
    if (endedAt != null && endedAt!.isBefore(startedAt)) {
      throw StateError('Session cannot end before it starts');
    }
  }
}
