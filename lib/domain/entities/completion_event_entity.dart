enum CompletionEventType {
  completed,
  skipped,
  notCompleted,
  rescheduled,
  overdue,
}

class CompletionEventEntity {
  const CompletionEventEntity({
    required this.id,
    required this.eventType,
    required this.eventAt,
    this.taskId,
    this.userId,
    this.source,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final CompletionEventType eventType;
  final DateTime eventAt;
  final String? taskId;
  final String? userId;
  final String? source;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'eventType': eventType.name,
      'eventAt': eventAt.toIso8601String(),
      'taskId': taskId,
      'userId': userId,
      'source': source,
      'metadata': metadata,
    };
  }

  factory CompletionEventEntity.fromJson(Map<String, dynamic> json) {
    return CompletionEventEntity(
      id: json['id']?.toString() ?? '',
      eventType: CompletionEventType.values.firstWhere(
        (CompletionEventType value) => value.name == json['eventType'],
        orElse: () => CompletionEventType.completed,
      ),
      eventAt: DateTime.tryParse(json['eventAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      taskId: json['taskId']?.toString(),
      userId: json['userId']?.toString(),
      source: json['source']?.toString(),
      metadata: _toStringMap(json['metadata']),
    );
  }

  static Map<String, dynamic> _toStringMap(dynamic value) {
    if (value is! Map) {
      return const <String, dynamic>{};
    }
    return value.map(
      (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }
}
