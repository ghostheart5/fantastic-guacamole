enum WorkWindowStatus { planned, active, completed, canceled }

class WorkWindowEntity {
  WorkWindowEntity({
    required this.id,
    required this.start,
    required this.end,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId,
    this.label,
    this.energyFloor = 1,
    this.energyCeiling = 5,
    this.preferredTaskIds = const <String>[],
    this.status = WorkWindowStatus.planned,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
       updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final DateTime start;
  final DateTime end;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final String? label;
  final int energyFloor;
  final int energyCeiling;
  final List<String> preferredTaskIds;
  final WorkWindowStatus status;

  Duration get duration => end.difference(start);

  bool get isValidRange => end.isAfter(start);

  WorkWindowEntity copyWith({
    DateTime? start,
    DateTime? end,
    String? label,
    int? energyFloor,
    int? energyCeiling,
    List<String>? preferredTaskIds,
    DateTime? updatedAt,
    String? userId,
    WorkWindowStatus? status,
  }) {
    return WorkWindowEntity(
      id: id,
      start: start ?? this.start,
      end: end ?? this.end,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      energyFloor: energyFloor ?? this.energyFloor,
      energyCeiling: energyCeiling ?? this.energyCeiling,
      preferredTaskIds: preferredTaskIds ?? this.preferredTaskIds,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'userId': userId,
      'label': label,
      'energyFloor': energyFloor,
      'energyCeiling': energyCeiling,
      'preferredTaskIds': preferredTaskIds,
      'status': status.name,
    };
  }

  factory WorkWindowEntity.fromJson(Map<String, dynamic> json) {
    return WorkWindowEntity(
      id: json['id']?.toString() ?? '',
      start:
          DateTime.tryParse(json['start']?.toString() ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(json['end']?.toString() ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      userId: json['userId']?.toString(),
      label: json['label']?.toString(),
      energyFloor: (json['energyFloor'] as num?)?.toInt() ?? 1,
      energyCeiling: (json['energyCeiling'] as num?)?.toInt() ?? 5,
      preferredTaskIds:
          (json['preferredTaskIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .toList(growable: false),
      status: WorkWindowStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => WorkWindowStatus.planned,
      ),
    );
  }
}
