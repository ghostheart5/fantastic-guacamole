enum HabitCadence { daily, weekly, monthly }

enum HabitStatus { active, paused, archived }

class HabitEntity {
  HabitEntity({
    required this.id,
    required this.title,
    required this.createdAt,
    DateTime? updatedAt,
    this.userId,
    this.description,
    this.cadence = HabitCadence.daily,
    this.targetCount = 1,
    this.status = HabitStatus.active,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final String? description;
  final HabitCadence cadence;
  final int targetCount;
  final HabitStatus status;

  bool get active => status == HabitStatus.active;

  HabitEntity copyWith({
    String? title,
    String? description,
    HabitCadence? cadence,
    int? targetCount,
    DateTime? updatedAt,
    String? userId,
    HabitStatus? status,
  }) {
    return HabitEntity(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      cadence: cadence ?? this.cadence,
      targetCount: targetCount ?? this.targetCount,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
      'cadence': cadence.name,
      'targetCount': targetCount,
      'status': status.name,
      'active': active,
    };
  }

  factory HabitEntity.fromJson(Map<String, dynamic> json) {
    return HabitEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Habit',
      userId: json['userId']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      description: json['description']?.toString(),
      cadence: HabitCadence.values.firstWhere(
        (value) => value.name == json['cadence']?.toString(),
        orElse: () => HabitCadence.daily,
      ),
      targetCount: ((json['targetCount'] as num?)?.toInt() ?? 1).clamp(1, 365),
      status: HabitStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () =>
            json['active'] == false ? HabitStatus.paused : HabitStatus.active,
      ),
    );
  }
}
