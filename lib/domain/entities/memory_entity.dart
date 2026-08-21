/// CHRONOSPARK-CLASS: SHIPPING | Feature: Governed memories
enum MemoryCategory {
  userPreference,
  goal,
  habit,
  task,
  reflection,
  lifeArea,
  planningGuidancePreference,
  value,
  importantDate,
  achievement,
  signal,
  other,
}

/// The product surface where a durable memory was explicitly created.
enum MemorySurface { smartPlanner, siConsole, creator, settings, unknown }

/// The narrow reason a durable memory may be used.
enum MemoryPurpose { guidancePreference, outcomeLearning, userNote, unknown }

/// The highest sensitivity represented by the exact stored text.
enum MemorySensitivity { standard, personal, emotional, crisis }

/// Records without affirmative consent are never eligible for retrieval.
enum MemoryConsentStatus { granted, withdrawn, legacyUnverified }

extension MemorySurfaceLabel on MemorySurface {
  String get label => switch (this) {
    MemorySurface.smartPlanner => 'Smart Planner',
    MemorySurface.siConsole => 'SI Console',
    MemorySurface.creator => 'Creator',
    MemorySurface.settings => 'Settings',
    MemorySurface.unknown => 'Unknown',
  };
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
    this.accountScopeId = '',
    this.sourceSurface = MemorySurface.unknown,
    this.purpose = MemoryPurpose.unknown,
    this.sensitivity = MemorySensitivity.personal,
    this.consentStatus = MemoryConsentStatus.legacyUnverified,
    this.consentedAt,
    this.expiresAt,
    this.provenance = '',
    this.whyStored = '',
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

  /// Opaque V2 namespace, never the user's raw account id.
  final String accountScopeId;
  final MemorySurface sourceSurface;
  final MemoryPurpose purpose;
  final MemorySensitivity sensitivity;
  final MemoryConsentStatus consentStatus;
  final DateTime? consentedAt;
  final DateTime? expiresAt;
  final String provenance;
  final String whyStored;

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
    String? accountScopeId,
    MemorySurface? sourceSurface,
    MemoryPurpose? purpose,
    MemorySensitivity? sensitivity,
    MemoryConsentStatus? consentStatus,
    DateTime? consentedAt,
    DateTime? expiresAt,
    String? provenance,
    String? whyStored,
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
      accountScopeId: accountScopeId ?? this.accountScopeId,
      sourceSurface: sourceSurface ?? this.sourceSurface,
      purpose: purpose ?? this.purpose,
      sensitivity: sensitivity ?? this.sensitivity,
      consentStatus: consentStatus ?? this.consentStatus,
      consentedAt: consentedAt ?? this.consentedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      provenance: provenance ?? this.provenance,
      whyStored: whyStored ?? this.whyStored,
    );
  }

  Duration get age => DateTime.now().difference(date);

  bool get isRecent => age.inDays < 3;

  bool get isArchived => archivedAt != null;

  bool isExpiredAt(DateTime now) {
    final DateTime? expiry = expiresAt;
    return expiry == null || !now.toUtc().isBefore(expiry.toUtc());
  }

  /// Durable recall is exact-account and exact-surface. SI durable
  /// interpretive memory is intentionally disabled in Phase 8.
  bool canBeRetrieved({
    required String requestingAccountScopeId,
    required MemorySurface requestingSurface,
    required DateTime now,
  }) {
    return accountScopeId.isNotEmpty &&
        accountScopeId == requestingAccountScopeId &&
        sourceSurface == requestingSurface &&
        requestingSurface != MemorySurface.siConsole &&
        consentStatus == MemoryConsentStatus.granted &&
        sensitivity != MemorySensitivity.emotional &&
        sensitivity != MemorySensitivity.crisis &&
        !isArchived &&
        !isExpiredAt(now);
  }

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

  /// Fail-closed validation used by every durable memory write.
  void validateForDurableStorage() {
    validate();
    final DateTime? consentTime = consentedAt;
    final DateTime? expiry = expiresAt;
    if (accountScopeId.trim().isEmpty ||
        sourceSurface == MemorySurface.unknown ||
        sourceSurface == MemorySurface.siConsole ||
        purpose == MemoryPurpose.unknown ||
        consentStatus != MemoryConsentStatus.granted ||
        consentTime == null ||
        expiry == null ||
        provenance.trim().isEmpty ||
        whyStored.trim().isEmpty) {
      throw StateError(
        'Durable memory requires account scope, allowed surface, purpose, consent, provenance, reason, and expiry.',
      );
    }
    if (sensitivity == MemorySensitivity.emotional ||
        sensitivity == MemorySensitivity.crisis) {
      throw StateError('Emotional and crisis disclosures must stay ephemeral.');
    }
    if (!expiry.toUtc().isAfter(date.toUtc()) ||
        expiry.toUtc().difference(date.toUtc()) > const Duration(days: 365)) {
      throw StateError('Durable memory expiry must be within one year.');
    }
    if (consentTime.toUtc().isBefore(date.toUtc())) {
      throw StateError('Consent time cannot precede memory creation.');
    }
  }

  MemoryReceipt toReceipt() => MemoryReceipt(
    memoryId: id,
    storedText: text,
    whyStored: whyStored,
    sourceSurface: sourceSurface,
    purpose: purpose,
    sensitivity: sensitivity,
    consentStatus: consentStatus,
    createdAt: date,
    consentedAt: consentedAt,
    expiresAt: expiresAt,
    provenance: provenance,
  );

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
    'accountScopeId': accountScopeId,
    'sourceSurface': sourceSurface.name,
    'purpose': purpose.name,
    'sensitivity': sensitivity.name,
    'consentStatus': consentStatus.name,
    'consentedAt': consentedAt?.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'provenance': provenance,
    'whyStored': whyStored,
  };

  factory MemoryEntity.fromJson(Map<String, dynamic> j) {
    final String storedCategory = j['category']?.toString() ?? 'other';
    final String categoryRaw = switch (storedCategory) {
      ('coa'
          'chingPreference') =>
        'planningGuidancePreference',
      ('jour'
          'nal') =>
        'reflection',
      ('ins'
          'ight') =>
        'signal',
      _ => storedCategory,
    };
    final MemoryCategory category = _enumOr(
      MemoryCategory.values,
      categoryRaw,
      MemoryCategory.other,
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
      id: j['id']?.toString() ?? '',
      text: j['text']?.toString() ?? '',
      date:
          DateTime.tryParse(j['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
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
      accountScopeId: j['accountScopeId']?.toString() ?? '',
      sourceSurface: _enumOr(
        MemorySurface.values,
        j['sourceSurface']?.toString(),
        MemorySurface.unknown,
      ),
      purpose: _enumOr(
        MemoryPurpose.values,
        j['purpose']?.toString(),
        MemoryPurpose.unknown,
      ),
      sensitivity: _enumOr(
        MemorySensitivity.values,
        j['sensitivity']?.toString(),
        MemorySensitivity.personal,
      ),
      consentStatus: _enumOr(
        MemoryConsentStatus.values,
        j['consentStatus']?.toString(),
        MemoryConsentStatus.legacyUnverified,
      ),
      consentedAt: DateTime.tryParse(j['consentedAt']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(j['expiresAt']?.toString() ?? ''),
      provenance: j['provenance']?.toString() ?? '',
      whyStored: j['whyStored']?.toString() ?? '',
    );
  }
}

class MemoryReceipt {
  const MemoryReceipt({
    required this.memoryId,
    required this.storedText,
    required this.whyStored,
    required this.sourceSurface,
    required this.purpose,
    required this.sensitivity,
    required this.consentStatus,
    required this.createdAt,
    required this.consentedAt,
    required this.expiresAt,
    required this.provenance,
  });

  final String memoryId;
  final String storedText;
  final String whyStored;
  final MemorySurface sourceSurface;
  final MemoryPurpose purpose;
  final MemorySensitivity sensitivity;
  final MemoryConsentStatus consentStatus;
  final DateTime createdAt;
  final DateTime? consentedAt;
  final DateTime? expiresAt;
  final String provenance;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'memoryId': memoryId,
    'storedText': storedText,
    'whyStored': whyStored,
    'sourceSurface': sourceSurface.name,
    'purpose': purpose.name,
    'sensitivity': sensitivity.name,
    'consentStatus': consentStatus.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'consentedAt': consentedAt?.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'provenance': provenance,
    'controls': const <String>['view', 'correct', 'export', 'delete'],
  };
}

T _enumOr<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final T value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
