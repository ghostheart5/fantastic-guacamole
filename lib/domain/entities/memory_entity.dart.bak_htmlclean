enum MemoryCategory {
  userPreference,
  goal,
  habit,
  task,
  journal,
  lifeArea,
  coachingPreference,
  value,
  importantDate,
  achievement,
  insight,
  other,
}

class MemoryLink {
  const MemoryLink({required this.memoryId, required this.relation});

  final String memoryId;
  final String relation;

  Map<String, dynamic> toJson() => {'memoryId': memoryId, 'relation': relation};

  factory MemoryLink.fromJson(Map<String, dynamic> json) => MemoryLink(
    memoryId: json['memoryId']?.toString() ?? '',
    relation: json['relation']?.toString() ?? 'related',
  );
}

class MemoryEntity {
  const MemoryEntity({
    required this.id,
    required this.text,
    required this.date,
    this.category = MemoryCategory.other,
    this.tags = const <String>[],
    this.links = const <MemoryLink>[],
    this.importance = 0.5,
    this.metadata = const <String, String>{},
    this.source = 'manual',
    this.archivedAt,
    this.starred = false,
  });

  final String id;
  final String text;
  final DateTime date;
  final MemoryCategory category;
  final List<String> tags;
  final List<MemoryLink> links;
  final double importance;
  final Map<String, String> metadata;
  final String source;
  final DateTime? archivedAt;
  final bool starred;

  MemoryEntity copyWith({
    String? text,
    DateTime? date,
    MemoryCategory? category,
    List<String>? tags,
    List<MemoryLink>? links,
    double? importance,
    Map<String, String>? metadata,
    String? source,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    bool? starred,
  }) {
    return MemoryEntity(
      id: id,
      text: text ?? this.text,
      date: date ?? this.date,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      links: links ?? this.links,
      importance: importance ?? this.importance,
      metadata: metadata ?? this.metadata,
      source: source ?? this.source,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      starred: starred ?? this.starred,
    );
  }

  // Domain behavior
  Duration get age => DateTime.now().difference(date);

  bool get isRecent => age.inDays < 3;

  bool get isArchived => archivedAt != null;

  MemoryEntity star() => copyWith(starred: true);

  MemoryEntity unstar() => copyWith(starred: false);

  MemoryEntity archive() => copyWith(archivedAt: DateTime.now());

  MemoryEntity unarchive() => copyWith(clearArchivedAt: true);

  MemoryEntity addLink(String otherMemoryId, {String relation = 'related'}) {
    if (otherMemoryId.trim().isEmpty || otherMemoryId == id) {
      return this;
    }
    final bool exists = links.any(
      (MemoryLink link) =>
          link.memoryId == otherMemoryId && link.relation == relation,
    );
    if (exists) {
      return this;
    }
    return copyWith(
      links: <MemoryLink>[
        ...links,
        MemoryLink(memoryId: otherMemoryId, relation: relation),
      ],
    );
  }

  bool contains(String query) =>
      text.toLowerCase().contains(query.toLowerCase()) ||
      tags.any((String tag) => tag.toLowerCase().contains(query.toLowerCase()));

  void validate() {
    if (text.trim().isEmpty) {
      throw StateError('MemoryEntity must have non-empty text');
    }
    if (importance < 0 || importance > 1) {
      throw StateError('MemoryEntity importance must be between 0 and 1');
    }
  }

  // Serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'date': date.toIso8601String(),
    'category': category.name,
    'tags': tags,
    'links': links.map((MemoryLink link) => link.toJson()).toList(),
    'importance': importance,
    'metadata': metadata,
    'source': source,
    'archivedAt': archivedAt?.toIso8601String(),
    'starred': starred,
  };

  factory MemoryEntity.fromJson(Map<String, dynamic> j) {
    final String categoryRaw = j['category']?.toString() ?? 'other';
    final MemoryCategory category = MemoryCategory.values.firstWhere(
      (MemoryCategory value) => value.name == categoryRaw,
      orElse: () => MemoryCategory.other,
    );

    final List<String> tags = (j['tags'] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);

    final List<MemoryLink> links =
        (j['links'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(MemoryLink.fromJson)
            .where((MemoryLink link) => link.memoryId.isNotEmpty)
            .toList(growable: false);

    final Map<String, String> metadata = <String, String>{};
    final Object? metadataRaw = j['metadata'];
    if (metadataRaw is Map) {
      for (final MapEntry<dynamic, dynamic> entry in metadataRaw.entries) {
        final String key = entry.key?.toString().trim() ?? '';
        final String value = entry.value?.toString().trim() ?? '';
        if (key.isNotEmpty && value.isNotEmpty) {
          metadata[key] = value;
        }
      }
    }

    return MemoryEntity(
      id: j['id'] as String,
      text: j['text'] as String,
      date: DateTime.parse(j['date'] as String),
      category: category,
      tags: tags,
      links: links,
      importance: (j['importance'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5,
      metadata: metadata,
      source: j['source']?.toString() ?? 'manual',
      archivedAt: j['archivedAt'] == null
          ? null
          : DateTime.tryParse(j['archivedAt'].toString()),
      starred: j['starred'] as bool? ?? false,
    );
  }
}
