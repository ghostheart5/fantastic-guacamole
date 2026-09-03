/// CHRONOSPARK-CLASS: SHIPPING | Feature: Workspace
///
/// Multi-workspace UI not built yet.
class WorkspaceEntity {
  WorkspaceEntity({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.activeModule = 'creator',
    Map<String, String> metadata = const <String, String>{},
  }) : metadata = Map<String, String>.unmodifiable(metadata);

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
  bool get isReview => activeModule == 'review';

  // Freshness logic
  Duration ageAt(DateTime reference) => reference.difference(updatedAt);
  Duration get age => ageAt(DateTime.now());
  bool isStaleAt(DateTime reference) => ageAt(reference).inMinutes > 10;
  bool get isStale => isStaleAt(DateTime.now());

  // Module transitions
  WorkspaceEntity switchModule(String module, {DateTime? at}) =>
      copyWith(activeModule: module, updatedAt: at ?? DateTime.now());

  // Metadata manipulation
  WorkspaceEntity addMetadata(String key, String value, {DateTime? at}) {
    final updated = Map<String, String>.from(metadata)..[key] = value;
    return copyWith(metadata: updated, updatedAt: at ?? DateTime.now());
  }

  WorkspaceEntity removeMetadata(String key, {DateTime? at}) {
    final updated = Map<String, String>.from(metadata)..remove(key);
    return copyWith(metadata: updated, updatedAt: at ?? DateTime.now());
  }

  // Invariants
  void validate() {
    if (name.trim().isEmpty) {
      throw StateError('WorkspaceEntity must have a name');
    }
  }
}
