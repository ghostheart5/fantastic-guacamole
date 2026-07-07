class FlowmapNodeEntity {
  const FlowmapNodeEntity({
    required this.id,
    required this.title,
    this.description,
    this.tags = const <String>[],
    this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final List<String> tags;
  final DateTime? createdAt;

  FlowmapNodeEntity copyWith({
    String? title,
    String? description,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return FlowmapNodeEntity(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
