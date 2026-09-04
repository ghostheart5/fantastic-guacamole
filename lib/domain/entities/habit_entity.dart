/// CHRONOSPARK-CLASS: SHIPPING | Feature: Future automation
///
/// Canonical Daily Rhythm model shared by habit and routine persistence.
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
    this.stepTaskIds = const <String>[],
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
  final List<String> stepTaskIds;
  final HabitStatus status;

  bool get active => status == HabitStatus.active;
  String get name => title;

  HabitEntity copyWith({
    String? title,
    String? description,
    HabitCadence? cadence,
    int? targetCount,
    List<String>? stepTaskIds,
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
      stepTaskIds: stepTaskIds ?? this.stepTaskIds,
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
      'stepTaskIds': stepTaskIds,
      'status': status.name,
      'active': active,
    };
  }

  factory HabitEntity.fromJson(Map<String, dynamic> json) {
    return HabitEntity(
      id: json['id']?.toString() ?? '',
      title:
          json['title']?.toString() ??
          json['name']?.toString() ??
          'Untitled Daily Rhythm',
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
      stepTaskIds: (json['stepTaskIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(growable: false),
      status: HabitStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () =>
            json['active'] == false ? HabitStatus.paused : HabitStatus.active,
      ),
    );
  }
}
