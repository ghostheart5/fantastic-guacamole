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

  // Semantic helpers
  bool get isCreator => activeModule == 'creator';
  bool get isPlanner => activeModule == 'planner';
  bool get isFocus => activeModule == 'focus';
  bool get isReview => activeModule == 'review';

  // Freshness logic
  Duration get age => DateTime.now().difference(updatedAt);
  bool get isStale => age.inMinutes > 10;

  // Module transitions
  WorkspaceEntity switchModule(String module) =>
      copyWith(activeModule: module, updatedAt: DateTime.now());

  // Metadata manipulation
  WorkspaceEntity addMetadata(String key, String value) {
    final updated = Map<String, String>.from(metadata)..[key] = value;
    return copyWith(metadata: updated, updatedAt: DateTime.now());
  }

  WorkspaceEntity removeMetadata(String key) {
    final updated = Map<String, String>.from(metadata)..remove(key);
    return copyWith(metadata: updated, updatedAt: DateTime.now());
  }

  // Invariants
  void validate() {
    if (name.trim().isEmpty) {
      throw StateError('WorkspaceEntity must have a name');
    }
  }
}
