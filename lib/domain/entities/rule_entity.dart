enum RuleStatus { enabled, disabled, archived }

class RuleEntity {
  RuleEntity({
    required this.id,
    required this.name,
    required this.condition,
    required this.effect,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId,
    this.status = RuleStatus.enabled,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
       updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final String name;
  final String condition;
  final String effect;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final RuleStatus status;

  bool get enabled => status == RuleStatus.enabled;

  RuleEntity copyWith({
    String? name,
    String? condition,
    String? effect,
    DateTime? updatedAt,
    String? userId,
    RuleStatus? status,
  }) {
    return RuleEntity(
      id: id,
      name: name ?? this.name,
      condition: condition ?? this.condition,
      effect: effect ?? this.effect,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'condition': condition,
      'effect': effect,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.name,
      'enabled': enabled,
    };
  }

  factory RuleEntity.fromJson(Map<String, dynamic> json) {
    return RuleEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Rule',
      condition: json['condition']?.toString() ?? '',
      effect: json['effect']?.toString() ?? '',
      userId: json['userId']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: RuleStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () =>
            json['enabled'] == false ? RuleStatus.disabled : RuleStatus.enabled,
      ),
    );
  }
}
