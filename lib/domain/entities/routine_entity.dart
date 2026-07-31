enum RoutineStatus { active, paused, archived }

enum RoutineCadence { daily, weekly, monthly }

class RoutineEntity {
  RoutineEntity({
    required this.id,
    required this.name,
    required this.createdAt,
    DateTime? updatedAt,
    this.userId,
    this.description,
    this.stepTaskIds = const <String>[],
    this.cadence = RoutineCadence.daily,
    this.targetCount = 1,
    this.status = RoutineStatus.active,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final String? description;
  final List<String> stepTaskIds;
  final RoutineCadence cadence;
  final int targetCount;
  final RoutineStatus status;

  bool get active => status == RoutineStatus.active;
  String get title => name;

  RoutineEntity copyWith({
    String? name,
    String? description,
    List<String>? stepTaskIds,
    RoutineCadence? cadence,
    int? targetCount,
    DateTime? updatedAt,
    String? userId,
    RoutineStatus? status,
  }) {
    return RoutineEntity(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      stepTaskIds: stepTaskIds ?? this.stepTaskIds,
      cadence: cadence ?? this.cadence,
      targetCount: targetCount ?? this.targetCount,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      // Title alias keeps habit-style naming compatible in downstream readers.
      'title': name,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
      'stepTaskIds': stepTaskIds,
      'cadence': cadence.name,
      'targetCount': targetCount,
      'status': status.name,
      'active': active,
    };
  }

  factory RoutineEntity.fromJson(Map<String, dynamic> json) {
    final String cadenceText =
        json['cadence']?.toString() ??
        json['recurrence']?.toString() ??
        json['frequency']?.toString() ??
        'daily';

    return RoutineEntity(
      id: json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ??
          json['title']?.toString() ??
          'Untitled Habit',
      userId: json['userId']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      description: json['description']?.toString(),
      stepTaskIds: (json['stepTaskIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      cadence: RoutineCadence.values.firstWhere(
        (RoutineCadence value) => value.name == cadenceText,
        orElse: () => RoutineCadence.daily,
      ),
      targetCount: ((json['targetCount'] as num?)?.toInt() ?? 1).clamp(1, 365),
      status: RoutineStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => json['active'] == false
            ? RoutineStatus.paused
            : RoutineStatus.active,
      ),
    );
  }
}
