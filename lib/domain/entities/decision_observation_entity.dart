/// CHRONOSPARK-CLASS: SHIPPING | Feature: Learning/adaptation
enum DecisionObservationType {
  recommendationShown,
  recommendationAccepted,
  recommendationRejected,
  taskCompleted,
  taskSkipped,
  taskRescheduled,
}

class DecisionObservationEntity {
  const DecisionObservationEntity({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.source,
    this.taskId,
  });

  final String id;
  final DecisionObservationType type;
  final DateTime timestamp;
  final String source;
  final String? taskId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'source': source,
    'taskId': taskId,
  };

  factory DecisionObservationEntity.fromJson(Map<String, dynamic> json) {
    return DecisionObservationEntity(
      id: json['id']?.toString() ?? '',
      type: DecisionObservationType.values.firstWhere(
        (DecisionObservationType value) =>
            value.name == json['type']?.toString(),
        orElse: () => DecisionObservationType.recommendationShown,
      ),
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      source: json['source']?.toString() ?? 'unknown',
      taskId: json['taskId']?.toString(),
    );
  }
}
