enum AutomationStatus { enabled, disabled, paused, archived }

class AutomationEntity {
  AutomationEntity({
    required this.id,
    required this.name,
    required this.trigger,
    required this.action,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId,
    this.status = AutomationStatus.enabled,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
       updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final String name;
  final String trigger;
  final String action;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final AutomationStatus status;

  bool get enabled => status == AutomationStatus.enabled;

  AutomationEntity copyWith({
    String? name,
    String? trigger,
    String? action,
    DateTime? updatedAt,
    String? userId,
    AutomationStatus? status,
  }) {
    return AutomationEntity(
      id: id,
      name: name ?? this.name,
      trigger: trigger ?? this.trigger,
      action: action ?? this.action,
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
      'trigger': trigger,
      'action': action,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.name,
      'enabled': enabled,
    };
  }

  factory AutomationEntity.fromJson(Map<String, dynamic> json) {
    return AutomationEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Automation',
      trigger: json['trigger']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      userId: json['userId']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: AutomationStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => json['enabled'] == false
            ? AutomationStatus.disabled
            : AutomationStatus.enabled,
      ),
    );
  }
}
