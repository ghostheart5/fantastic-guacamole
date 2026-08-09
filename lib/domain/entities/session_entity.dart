class SessionEntity {
  const SessionEntity({
    required this.id,
    required this.taskId,
    required this.startedAt,
    this.endedAt,
    required this.plannedDuration,
    this.pausedAt,
    this.pausedDuration = Duration.zero,
  });

  final String id;
  final String taskId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration plannedDuration;
  final DateTime? pausedAt;
  final Duration pausedDuration;

  bool get isPaused => pausedAt != null;

  Duration get actualDuration {
    final end = endedAt;
    return end == null
        ? Duration.zero
        : end.difference(startedAt) - pausedDuration;
  }

  bool get isCompleted => endedAt != null;

  Duration get remaining {
    if (endedAt != null) return Duration.zero;
    final DateTime now = DateTime.now();
    final Duration activePause = pausedAt == null
        ? Duration.zero
        : now.difference(pausedAt!);
    final elapsed = now.difference(startedAt) - pausedDuration - activePause;
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
    return endAt(DateTime.now());
  }

  SessionEntity endAt(DateTime endedAt) {
    final DateTime? activePauseStartedAt = pausedAt;
    final Duration finalPausedDuration = activePauseStartedAt == null
        ? pausedDuration
        : pausedDuration + endedAt.difference(activePauseStartedAt);
    return SessionEntity(
      id: id,
      taskId: taskId,
      startedAt: startedAt,
      endedAt: endedAt,
      plannedDuration: plannedDuration,
      pausedDuration: finalPausedDuration,
    );
  }

  SessionEntity pauseAt(DateTime pauseTime) {
    if (endedAt != null) {
      throw StateError('Cannot pause an ended session.');
    }
    if (pausedAt != null) return this;
    if (pauseTime.isBefore(startedAt)) {
      throw StateError('Session cannot pause before it starts.');
    }
    return SessionEntity(
      id: id,
      taskId: taskId,
      startedAt: startedAt,
      endedAt: endedAt,
      plannedDuration: plannedDuration,
      pausedAt: pauseTime,
      pausedDuration: pausedDuration,
    );
  }

  SessionEntity resumeAt(DateTime resumeTime) {
    final DateTime? activePauseStartedAt = pausedAt;
    if (activePauseStartedAt == null) return this;
    if (resumeTime.isBefore(activePauseStartedAt)) {
      throw StateError('Session cannot resume before it pauses.');
    }
    return SessionEntity(
      id: id,
      taskId: taskId,
      startedAt: startedAt,
      endedAt: endedAt,
      plannedDuration: plannedDuration,
      pausedDuration:
          pausedDuration + resumeTime.difference(activePauseStartedAt),
    );
  }

  void validate() {
    if (endedAt != null && endedAt!.isBefore(startedAt)) {
      throw StateError('Session cannot end before it starts');
    }
    if (pausedAt != null && pausedAt!.isBefore(startedAt)) {
      throw StateError('Session cannot pause before it starts');
    }
  }
}
