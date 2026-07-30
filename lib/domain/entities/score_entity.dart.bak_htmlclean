enum ScoreStatus { provisional, validated, archived }

class ScoreEntity {
  ScoreEntity({
    required this.id,
    required this.value,
    required this.kind,
    required this.recordedAt,
    DateTime? updatedAt,
    this.userId,
    this.metadata = const <String, Object?>{},
    this.status = ScoreStatus.provisional,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final double value;
  final String kind;
  final DateTime recordedAt;
  final DateTime updatedAt;
  final String? userId;
  final Map<String, Object?> metadata;
  final ScoreStatus status;

  ScoreEntity copyWith({
    double? value,
    String? kind,
    DateTime? recordedAt,
    DateTime? updatedAt,
    String? userId,
    Map<String, Object?>? metadata,
    ScoreStatus? status,
  }) {
    return ScoreEntity(
      id: id,
      value: value ?? this.value,
      kind: kind ?? this.kind,
      recordedAt: recordedAt ?? this.recordedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'value': value,
      'kind': kind,
      'recordedAt': recordedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'userId': userId,
      'metadata': metadata,
      'status': status.name,
    };
  }

  factory ScoreEntity.fromJson(Map<String, dynamic> json) {
    return ScoreEntity(
      id: json['id']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      kind: json['kind']?.toString() ?? 'generic',
      recordedAt:
          DateTime.tryParse(json['recordedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      userId: json['userId']?.toString(),
      metadata:
          (json['metadata'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          const <String, Object?>{},
      status: ScoreStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => ScoreStatus.provisional,
      ),
    );
  }
}
