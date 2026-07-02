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
    final DateTime? end = endedAt;
    return end == null ? Duration.zero : end.difference(startedAt);
  }
}
