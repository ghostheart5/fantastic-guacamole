class WorkspaceEntity {
  const WorkspaceEntity({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.activeModule = 'creator',
    this.metadata = const <String, String>{},
  });

  final String id;
  final String name;
  final DateTime updatedAt;
  final String activeModule;
  final Map<String, String> metadata;

  WorkspaceEntity copyWith({
    String? id,
    String? name,
    DateTime? updatedAt,
    String? activeModule,
    Map<String, String>? metadata,
  }) {
    return WorkspaceEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      activeModule: activeModule ?? this.activeModule,
      metadata: metadata ?? this.metadata,
    );
  }
}
