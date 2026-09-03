/// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner/SI signals
///
/// Wired through data + domain; does not reach the UI yet.
class SignalEntity {
  SignalEntity({
    required this.id,
    required this.title,
    required this.summary,
    required this.createdAt,
    List<String> tags = const <String>[],
    this.action,
  }) : tags = List<String>.unmodifiable(tags);

  final String id;
  final String title;
  final String summary;
  final DateTime createdAt;
  final List<String> tags;
  final String? action;

  SignalEntity copyWith({
    String? id,
    String? title,
    String? summary,
    DateTime? createdAt,
    List<String>? tags,
    String? action,
  }) {
    return SignalEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      action: action ?? this.action,
    );
  }

  // Domain behavior
  SignalEntity addTag(String tag) =>
      tags.contains(tag) ? this : copyWith(tags: [...tags, tag]);

  SignalEntity removeTag(String tag) =>
      copyWith(tags: tags.where((t) => t != tag).toList());

  bool get hasAction => action != null && action!.isNotEmpty;

  bool isRecentAt(DateTime reference) => ageAt(reference).inDays < 7;

  bool get isRecent => isRecentAt(DateTime.now());

  Duration ageAt(DateTime reference) => reference.difference(createdAt);

  Duration get age => ageAt(DateTime.now());

  bool matches(String query) {
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        summary.toLowerCase().contains(q) ||
        tags.any((t) => t.toLowerCase().contains(q));
  }

  void validate() {
    if (title.trim().isEmpty) {
      throw StateError('SignalEntity must have a title');
    }
  }
}
