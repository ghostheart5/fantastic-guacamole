enum CreatorSavedKind { task, goal, routine, note, plan }

class CreatorCreationReceipt {
  CreatorCreationReceipt({
    String? id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.whyItMatters = '',
    this.nextAction = '',
  }) : id = id ?? '${kind.name}:${createdAt.toUtc().toIso8601String()}';

  final String id;
  final CreatorSavedKind kind;
  final String title;
  final DateTime createdAt;
  final String whyItMatters;
  final String nextAction;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'id': id,
    'kind': kind.name,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'whyItMatters': whyItMatters,
    'nextAction': nextAction,
  };

  static CreatorCreationReceipt? fromJson(Object? value) {
    if (value is! Map) return null;
    final Map<String, dynamic> json = value.map<String, dynamic>(
      (dynamic key, dynamic item) => MapEntry(key.toString(), item),
    );
    final String title = json['title']?.toString().trim() ?? '';
    final DateTime? createdAt = DateTime.tryParse(
      json['createdAt']?.toString() ?? '',
    );
    final String kindName = json['kind']?.toString() ?? '';
    CreatorSavedKind? kind;
    for (final CreatorSavedKind candidate in CreatorSavedKind.values) {
      if (candidate.name == kindName) {
        kind = candidate;
        break;
      }
    }
    if (title.isEmpty || createdAt == null || kind == null) return null;
    final String? storedId = json['id']?.toString().trim();
    return CreatorCreationReceipt(
      id: storedId == null || storedId.isEmpty ? null : storedId,
      kind: kind,
      title: title,
      createdAt: createdAt,
      whyItMatters: json['whyItMatters']?.toString().trim() ?? '',
      nextAction: json['nextAction']?.toString().trim() ?? '',
    );
  }
}
