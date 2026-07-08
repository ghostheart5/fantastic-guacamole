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

  // Domain behavior
  InsightEntity addTag(String tag) =>
      tags.contains(tag) ? this : copyWith(tags: [...tags, tag]);

  InsightEntity removeTag(String tag) =>
      copyWith(tags: tags.where((t) => t != tag).toList());

  bool get hasAction => action != null && action!.isNotEmpty;

  bool get isRecent => DateTime.now().difference(createdAt).inDays < 7;

  Duration get age => DateTime.now().difference(createdAt);

  bool matches(String query) {
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        summary.toLowerCase().contains(q) ||
        tags.any((t) => t.toLowerCase().contains(q));
  }

  void validate() {
    if (title.trim().isEmpty) {
      throw StateError('InsightEntity must have a title');
    }
  }
}
