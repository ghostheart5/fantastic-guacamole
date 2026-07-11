enum TemplateStatus { draft, active, archived }

class TemplateEntity {
  TemplateEntity({
    required this.id,
    required this.name,
    required this.createdAt,
    DateTime? updatedAt,
    this.userId,
    this.description,
    this.blockIds = const <String>[],
    this.status = TemplateStatus.active,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final String? description;
  final List<String> blockIds;
  final TemplateStatus status;

  bool get active => status == TemplateStatus.active;

  TemplateEntity copyWith({
    String? name,
    String? description,
    List<String>? blockIds,
    DateTime? updatedAt,
    String? userId,
    TemplateStatus? status,
  }) {
    return TemplateEntity(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      blockIds: blockIds ?? this.blockIds,
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
      'blockIds': blockIds,
      'status': status.name,
      'active': active,
    };
  }

  factory TemplateEntity.fromJson(Map<String, dynamic> json) {
    return TemplateEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Template',
      userId: json['userId']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      description: json['description']?.toString(),
      blockIds: (json['blockIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false),
      status: TemplateStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => json['active'] == false
            ? TemplateStatus.draft
            : TemplateStatus.active,
      ),
    );
  }
}
