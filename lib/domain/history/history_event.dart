/// The durable, feature-neutral record of something that happened in a life.
///
/// A history event is a fact, not current state and not a Timeline projection.
enum HistoryEventKind {
  reflectionRecorded,
  taskCreated,
  taskCompleted,
  taskSkipped,
  taskRescheduled,
  taskScheduled,
  goalScheduled,
  goalCompleted,
  habitScheduled,
  milestoneReached,
  streakRecorded,
  deadlineScheduled,
  projectUpdated,
  legacyTimeline,
}

enum HistoryEntityType {
  task,
  goal,
  habit,
  routine,
  plan,
  note,
  reflection,
  milestone,
  project,
  unknown,
}

enum HistoryEventSource {
  creator,
  user,
  smartPlanner,
  system,
  siApproved,
  importMigration,
  unknown,
}

class HistoryEvent {
  const HistoryEvent({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.entityType,
    required this.source,
    this.entityId,
    this.payload = const <String, dynamic>{},
    this.legacyKind,
    this.version = 1,
  });

  final String id;
  final HistoryEventKind kind;
  final DateTime occurredAt;
  final HistoryEntityType entityType;
  final String? entityId;
  final HistoryEventSource source;
  final Map<String, dynamic> payload;
  final String? legacyKind;
  final int version;

  bool get isLegacy => kind == HistoryEventKind.legacyTimeline;

  void validate() {
    if (id.trim().isEmpty) {
      throw StateError('HistoryEvent requires an id.');
    }
    if (isLegacy && (legacyKind == null || legacyKind!.trim().isEmpty)) {
      throw StateError('Legacy HistoryEvent requires its original kind.');
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': version,
    'id': id,
    'kind': kind.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'entityType': entityType.name,
    'entityId': entityId,
    'source': source.name,
    'payload': payload,
    'legacyKind': legacyKind,
  };

  factory HistoryEvent.fromJson(Map<String, dynamic> json) {
    final String rawKind = json['kind']?.toString() ?? '';
    final HistoryEventKind kind = HistoryEventKind.values.firstWhere(
      (HistoryEventKind value) => value.name == rawKind,
      orElse: () => HistoryEventKind.legacyTimeline,
    );
    final DateTime occurredAt =
        DateTime.tryParse(json['occurredAt']?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return HistoryEvent(
      id: json['id']?.toString() ?? '',
      kind: kind,
      occurredAt: occurredAt,
      entityType: _enumOrUnknown(
        HistoryEntityType.values,
        json['entityType']?.toString(),
        HistoryEntityType.unknown,
      ),
      entityId: json['entityId']?.toString(),
      source: _enumOrUnknown(
        HistoryEventSource.values,
        json['source']?.toString(),
        HistoryEventSource.unknown,
      ),
      payload: _stringMap(json['payload']),
      legacyKind: kind == HistoryEventKind.legacyTimeline
          ? (json['legacyKind']?.toString() ?? rawKind)
          : json['legacyKind']?.toString(),
      version: json['schemaVersion'] is int ? json['schemaVersion'] as int : 1,
    );
  }

  static T _enumOrUnknown<T extends Enum>(
    List<T> values,
    String? raw,
    T fallback,
  ) => values.firstWhere((T value) => value.name == raw, orElse: () => fallback);

  static Map<String, dynamic> _stringMap(Object? raw) {
    if (raw is! Map) return const <String, dynamic>{};
    return raw.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }
}
