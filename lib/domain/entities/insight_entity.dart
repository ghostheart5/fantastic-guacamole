class InsightEntity {
  const InsightEntity({
    required this.id,
    required this.title,
    required this.summary,
    required this.createdAt,
    this.tags = const <String>[],
    this.action,
  });

  final String id;
  final String title;
  final String summary;
  final DateTime createdAt;
  final List<String> tags;
  final String? action;

  InsightEntity copyWith({
    String? id,
    String? title,
    String? summary,
    DateTime? createdAt,
    List<String>? tags,
    String? action,
  }) {
    return InsightEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      action: action ?? this.action,
    );
  }
}
