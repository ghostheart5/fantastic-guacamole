enum RoutineStatus { active, paused, archived }

class RoutineEntity {
  RoutineEntity({
    required this.id,
    required this.name,
    required this.createdAt,
    DateTime? updatedAt,
    this.userId,
    this.description,
    this.stepTaskIds = const <String>[],
    this.status = RoutineStatus.active,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final String? description;
  final List<String> stepTaskIds;
  final RoutineStatus status;

  bool get active => status == RoutineStatus.active;

  RoutineEntity copyWith({
    String? name,
    String? description,
    List<String>? stepTaskIds,
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
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
      'stepTaskIds': stepTaskIds,
      'status': status.name,
      'active': active,
    };
  }

  factory RoutineEntity.fromJson(Map<String, dynamic> json) {
    return RoutineEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Routine',
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
      status: RoutineStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => json['active'] == false
            ? RoutineStatus.paused
            : RoutineStatus.active,
      ),
    );
  }
}
