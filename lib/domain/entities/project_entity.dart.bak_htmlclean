enum ProjectStatus { active, archived }

class ProjectEntity {
  ProjectEntity({
    required this.id,
    required this.name,
    required this.createdAt,
    DateTime? updatedAt,
    this.userId,
    this.description,
    this.colorHex = 0xFF00E5FF,
    this.status = ProjectStatus.active,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;
  final String? description;
  final int colorHex;
  final ProjectStatus status;

  bool get archived => status == ProjectStatus.archived;

  ProjectEntity copyWith({
    String? name,
    String? description,
    int? colorHex,
    DateTime? updatedAt,
    String? userId,
    ProjectStatus? status,
  }) {
    return ProjectEntity(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
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
      'colorHex': colorHex,
      'status': status.name,
      'archived': archived,
    };
  }

  factory ProjectEntity.fromJson(Map<String, dynamic> json) {
    return ProjectEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Project',
      userId: json['userId']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      description: json['description']?.toString(),
      colorHex: (json['colorHex'] as num?)?.toInt() ?? 0xFF00E5FF,
      status: ProjectStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => json['archived'] == true
            ? ProjectStatus.archived
            : ProjectStatus.active,
      ),
    );
  }
}
