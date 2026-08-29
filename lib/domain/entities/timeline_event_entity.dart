/// CHRONOSPARK-CLASS: SHIPPING | Feature: Calendar/timeline
enum TimelineEventType {
  reflection,
  levelUp,
  goalComplete,
  streak,
  task,
  goal,
  habit,
  project,
  milestone,
  deadline,
  forecast,
  snapshot,
  risk,
  recommendation,
  noteCreated,
  noteUpdated,
  noteArchived,
  noteDeleted,
}

enum TimelineEventStatus {
  planned,
  active,
  completed,
  skipped,
  canceled,
  overdue,
  atRisk,
  info,
}

class TimelineEventEntity {
  const TimelineEventEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.timestamp,
    this.status = TimelineEventStatus.info,
    this.dueAt,
    this.phase,
    this.relatedId,
    this.sourceFeature,
    this.decisionId,
    this.userOverride = false,
  });

  final String id;
  final TimelineEventType type;
  final String title;
  final String detail;
  final DateTime timestamp;
  final TimelineEventStatus status;
  final DateTime? dueAt;
  final String? phase;
  final String? relatedId;

  /// Provenance makes adaptive decisions auditable without storing raw prompts.
  final String? sourceFeature;
  final String? decisionId;
  final bool userOverride;

  // Semantic helpers
  bool get isReflection => type == TimelineEventType.reflection;
  bool get isLevelUp => type == TimelineEventType.levelUp;
  bool get isGoalComplete => type == TimelineEventType.goalComplete;
  bool get isStreak => type == TimelineEventType.streak;
  bool get isMilestone =>
      type == TimelineEventType.goalComplete ||
      type == TimelineEventType.levelUp ||
      type == TimelineEventType.streak ||
      type == TimelineEventType.milestone;
  bool get isRisk =>
      type == TimelineEventType.risk || status == TimelineEventStatus.atRisk;
  bool get isRecommendation => type == TimelineEventType.recommendation;
  bool get isNoteCreated => type == TimelineEventType.noteCreated;
  bool get isNoteUpdated => type == TimelineEventType.noteUpdated;
  bool get isNoteArchived => type == TimelineEventType.noteArchived;
  bool get isNoteDeleted => type == TimelineEventType.noteDeleted;
  bool get isDeadline => type == TimelineEventType.deadline;
  bool get isForecast => type == TimelineEventType.forecast;
  bool get isOverdue => status == TimelineEventStatus.overdue;
  bool get isSkipped => status == TimelineEventStatus.skipped;
  bool get isCanceled => status == TimelineEventStatus.canceled;
  bool isUpcomingAt(DateTime reference) {
    final DateTime? due = dueAt;
    if (due == null) {
      return false;
    }
    final Duration delta = due.difference(reference);
    return !isOverdue && delta.inDays <= 7 && delta.inHours >= 0;
  }

  bool get isUpcoming => isUpcomingAt(DateTime.now());

  // Recency logic
  Duration ageAt(DateTime reference) => reference.difference(timestamp);
  Duration get age => ageAt(DateTime.now());
  bool isRecentAt(DateTime reference) => ageAt(reference).inHours < 24;
  bool get isRecent => isRecentAt(DateTime.now());

  // Display helpers
  String get shortLabel {
    switch (type) {
      case TimelineEventType.reflection:
        return 'Reflection';
      case TimelineEventType.levelUp:
        return 'Level Up';
      case TimelineEventType.goalComplete:
        return 'Goal Complete';
      case TimelineEventType.streak:
        return 'Streak';
      case TimelineEventType.task:
        return 'Task';
      case TimelineEventType.goal:
        return 'Goal';
      case TimelineEventType.habit:
        return 'Habit';
      case TimelineEventType.project:
        return 'Project';
      case TimelineEventType.milestone:
        return 'Milestone';
      case TimelineEventType.deadline:
        return 'Deadline';
      case TimelineEventType.forecast:
        return 'Forecast';
      case TimelineEventType.snapshot:
        return 'Snapshot';
      case TimelineEventType.risk:
        return 'Risk';
      case TimelineEventType.recommendation:
        return 'Recommendation';
      case TimelineEventType.noteCreated:
        return 'Note Created';
      case TimelineEventType.noteUpdated:
        return 'Note Updated';
      case TimelineEventType.noteArchived:
        return 'Note Archived';
      case TimelineEventType.noteDeleted:
        return 'Note Deleted';
    }
  }

  // Invariants
  void validate() {
    if (title.trim().isEmpty) {
      throw StateError('TimelineEventEntity must have a title');
    }
    if (detail.trim().isEmpty) {
      throw StateError('TimelineEventEntity must have detail text');
    }
    final DateTime? due = dueAt;
    if (status == TimelineEventStatus.overdue && due == null) {
      throw StateError('Overdue timeline event must include dueAt');
    }
  }

  TimelineEventEntity copyWith({
    TimelineEventType? type,
    String? title,
    String? detail,
    DateTime? timestamp,
    TimelineEventStatus? status,
    DateTime? dueAt,
    bool clearDueAt = false,
    String? phase,
    String? relatedId,
    String? sourceFeature,
    String? decisionId,
    bool? userOverride,
  }) {
    return TimelineEventEntity(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      phase: phase ?? this.phase,
      relatedId: relatedId ?? this.relatedId,
      sourceFeature: sourceFeature ?? this.sourceFeature,
      decisionId: decisionId ?? this.decisionId,
      userOverride: userOverride ?? this.userOverride,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'detail': detail,
    'timestamp': timestamp.toIso8601String(),
    'status': status.name,
    'dueAt': dueAt?.toIso8601String(),
    'phase': phase,
    'relatedId': relatedId,
    'sourceFeature': sourceFeature,
    'decisionId': decisionId,
    'userOverride': userOverride,
  };

  factory TimelineEventEntity.fromJson(Map<String, dynamic> j) =>
      TimelineEventEntity(
        id: j['id'] as String,
        type: TimelineEventType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => TimelineEventType.reflection,
        ),
        title: j['title'] as String,
        detail: j['detail'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        status: TimelineEventStatus.values.firstWhere(
          (TimelineEventStatus value) => value.name == j['status'],
          orElse: () => TimelineEventStatus.info,
        ),
        dueAt: j['dueAt'] == null
            ? null
            : DateTime.tryParse(j['dueAt'].toString()),
        phase: j['phase']?.toString(),
        relatedId: j['relatedId']?.toString(),
        sourceFeature: j['sourceFeature']?.toString(),
        decisionId: j['decisionId']?.toString(),
        userOverride: j['userOverride'] as bool? ?? false,
      );
}
