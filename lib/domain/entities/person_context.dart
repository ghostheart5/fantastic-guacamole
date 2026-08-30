/// CHRONOSPARK-CLASS: SHIPPING | Feature: Governed person context
enum PersonContextKind {
  role,
  value,
  currentPriority,
  lifeArea,
  presentCapacity,
  preferredSupportStyle,
  boundary,
  importantRelationship,
  commitment,
  outcomeHistory,
}

enum PersonContextSource { userAuthored, confirmedOutcome }

enum PersonContextConsent { granted, withdrawn }

enum PersonContextPurpose {
  planningGuidance,
  decisionSupport,
  reflection,
  outcomeLearning,
}

enum PersonContextSurface {
  smartPlanner,
  siConsole,
  nexus,
  trajectory,
  creator,
  settings,
}

enum PersonContextKnowledge { known, unknown }

enum PersonContextExportBehavior { include, exclude }

enum PersonContextDeletionBehavior {
  userRemovable,
  expiresAutomatically,
  deleteWithAccount,
}

final class PersonContextCorrection {
  const PersonContextCorrection({
    required this.previousValue,
    required this.correctedAt,
    required this.reason,
  });

  final String previousValue;
  final DateTime correctedAt;
  final String reason;

  static const int maxReasonLength = 240;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'previousValue': previousValue,
    'correctedAt': correctedAt.toUtc().toIso8601String(),
    'reason': reason,
  };

  factory PersonContextCorrection.fromJson(Map<String, dynamic> json) {
    final String previousValue = _requiredString(json, 'previousValue');
    final DateTime correctedAt = _requiredDate(json, 'correctedAt');
    final String reason = _requiredString(json, 'reason');
    return PersonContextCorrection(
      previousValue: previousValue,
      correctedAt: correctedAt,
      reason: reason,
    );
  }
}

final class PersonContextSignal {
  PersonContextSignal({
    required this.id,
    required this.kind,
    required this.value,
    required this.source,
    required this.consent,
    required this.purpose,
    required Set<PersonContextSurface> surfaceScopes,
    required this.recordedAt,
    required this.freshUntil,
    required this.expiresAt,
    required this.exportBehavior,
    required this.deletionBehavior,
    this.consentedAt,
    this.knowledge = PersonContextKnowledge.known,
    List<PersonContextCorrection> corrections =
        const <PersonContextCorrection>[],
  }) : surfaceScopes = Set<PersonContextSurface>.unmodifiable(surfaceScopes),
       corrections = List<PersonContextCorrection>.unmodifiable(corrections) {
    validate();
  }

  static const int maxCorrectionHistory = 20;
  static const int maxIdLength = 128;
  static const int maxValueLength = 1000;

  final String id;
  final PersonContextKind kind;
  final String value;
  final PersonContextSource source;
  final PersonContextConsent consent;
  final DateTime? consentedAt;
  final PersonContextPurpose purpose;
  final Set<PersonContextSurface> surfaceScopes;
  final DateTime recordedAt;
  final DateTime freshUntil;
  final DateTime expiresAt;
  final List<PersonContextCorrection> corrections;
  final PersonContextExportBehavior exportBehavior;
  final PersonContextDeletionBehavior deletionBehavior;
  final PersonContextKnowledge knowledge;

  bool isAvailableTo(PersonContextSurface surface, DateTime now) {
    final DateTime reference = now.toUtc();
    final DateTime? consented = consentedAt?.toUtc();
    return knowledge == PersonContextKnowledge.known &&
        value.trim().isNotEmpty &&
        consent == PersonContextConsent.granted &&
        consented != null &&
        !reference.isBefore(consented) &&
        surfaceScopes.contains(surface) &&
        !reference.isBefore(recordedAt.toUtc()) &&
        !reference.isAfter(freshUntil.toUtc()) &&
        reference.isBefore(expiresAt.toUtc());
  }

  PersonContextSignal corrected({
    required String value,
    required DateTime correctedAt,
    required String reason,
    required DateTime freshUntil,
    required DateTime expiresAt,
  }) {
    final String normalized = value.trim();
    final String normalizedReason = reason.trim();
    if (normalized.isEmpty || normalizedReason.isEmpty) {
      throw ArgumentError('A correction requires a value and reason.');
    }
    final List<PersonContextCorrection> history = <PersonContextCorrection>[
      ...corrections,
      PersonContextCorrection(
        previousValue: this.value,
        correctedAt: correctedAt.toUtc(),
        reason: normalizedReason,
      ),
    ];
    return PersonContextSignal(
      id: id,
      kind: kind,
      value: normalized,
      source: PersonContextSource.userAuthored,
      consent: consent,
      consentedAt: consentedAt,
      purpose: purpose,
      surfaceScopes: surfaceScopes,
      recordedAt: correctedAt.toUtc(),
      freshUntil: freshUntil.toUtc(),
      expiresAt: expiresAt.toUtc(),
      corrections: history.length <= maxCorrectionHistory
          ? history
          : history.sublist(history.length - maxCorrectionHistory),
      exportBehavior: exportBehavior,
      deletionBehavior: deletionBehavior,
      knowledge: PersonContextKnowledge.known,
    );
  }

  void validate() {
    final String normalizedId = id.trim();
    final String normalizedValue = value.trim();
    if (normalizedId.isEmpty ||
        normalizedId != id ||
        normalizedId.length > maxIdLength) {
      throw StateError('Person context signal id must be normalized.');
    }
    if (normalizedValue.length > maxValueLength) {
      throw StateError('Person context value is too long.');
    }
    if (knowledge == PersonContextKnowledge.known && normalizedValue.isEmpty) {
      throw StateError('Known person context requires a value.');
    }
    if (knowledge == PersonContextKnowledge.unknown &&
        normalizedValue.isNotEmpty) {
      throw StateError('Unknown person context cannot carry a value.');
    }
    if (surfaceScopes.isEmpty) {
      throw StateError('Person context requires at least one surface scope.');
    }
    if (consent == PersonContextConsent.granted && consentedAt == null) {
      throw StateError('Granted person context requires a consent timestamp.');
    }
    final DateTime recorded = recordedAt.toUtc();
    final DateTime fresh = freshUntil.toUtc();
    final DateTime expiry = expiresAt.toUtc();
    if (fresh.isBefore(recorded) || expiry.isBefore(fresh)) {
      throw StateError('Person context freshness and expiry are inconsistent.');
    }
    final DateTime? consented = consentedAt?.toUtc();
    if (consented != null && consented.isAfter(expiry)) {
      throw StateError('Person context consent cannot follow its expiry.');
    }
    if (expiry.difference(recorded) > const Duration(days: 366)) {
      throw StateError('Person context must be reviewed within one year.');
    }
    if (kind == PersonContextKind.presentCapacity &&
        fresh.difference(recorded) > const Duration(hours: 24)) {
      throw StateError('Present capacity cannot remain fresh beyond 24 hours.');
    }
    if (source == PersonContextSource.confirmedOutcome &&
        kind != PersonContextKind.outcomeHistory) {
      throw StateError('Confirmed outcomes cannot become lasting identity.');
    }
    if (corrections.length > maxCorrectionHistory) {
      throw StateError('Person context correction history is unbounded.');
    }
    DateTime? priorCorrection;
    for (final PersonContextCorrection correction in corrections) {
      if (correction.reason.trim().isEmpty ||
          correction.reason.length > PersonContextCorrection.maxReasonLength ||
          correction.previousValue.trim().isEmpty ||
          correction.previousValue.length > maxValueLength) {
        throw StateError('Person context corrections must be reviewable.');
      }
      final DateTime corrected = correction.correctedAt.toUtc();
      if (corrected.isAfter(recorded) ||
          (priorCorrection != null && corrected.isBefore(priorCorrection))) {
        throw StateError('Person context corrections are out of order.');
      }
      priorCorrection = corrected;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind.name,
    'value': value,
    'source': source.name,
    'consent': consent.name,
    'consentedAt': consentedAt?.toUtc().toIso8601String(),
    'purpose': purpose.name,
    'surfaceScopes': surfaceScopes.map((value) => value.name).toList()..sort(),
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'freshUntil': freshUntil.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'corrections': corrections.map((value) => value.toJson()).toList(),
    'exportBehavior': exportBehavior.name,
    'deletionBehavior': deletionBehavior.name,
    'knowledge': knowledge.name,
  };

  factory PersonContextSignal.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawScopes = _requiredList(json, 'surfaceScopes');
    final List<dynamic> rawCorrections = _requiredList(json, 'corrections');
    return PersonContextSignal(
      id: _requiredString(json, 'id'),
      kind: _requiredEnum(json, 'kind', PersonContextKind.values),
      value: json['value'] is String
          ? json['value'] as String
          : _invalid('value'),
      source: _requiredEnum(json, 'source', PersonContextSource.values),
      consent: _requiredEnum(json, 'consent', PersonContextConsent.values),
      consentedAt: _optionalDate(json, 'consentedAt'),
      purpose: _requiredEnum(json, 'purpose', PersonContextPurpose.values),
      surfaceScopes: rawScopes
          .map(
            (dynamic value) => _enumFromString(
              value,
              'surfaceScopes',
              PersonContextSurface.values,
            ),
          )
          .toSet(),
      recordedAt: _requiredDate(json, 'recordedAt'),
      freshUntil: _requiredDate(json, 'freshUntil'),
      expiresAt: _requiredDate(json, 'expiresAt'),
      corrections: rawCorrections
          .map(
            (dynamic value) => PersonContextCorrection.fromJson(
              _stringMap(value, 'corrections'),
            ),
          )
          .toList(growable: false),
      exportBehavior: _requiredEnum(
        json,
        'exportBehavior',
        PersonContextExportBehavior.values,
      ),
      deletionBehavior: _requiredEnum(
        json,
        'deletionBehavior',
        PersonContextDeletionBehavior.values,
      ),
      knowledge: _requiredEnum(
        json,
        'knowledge',
        PersonContextKnowledge.values,
      ),
    );
  }
}

final class PersonContextSpine {
  PersonContextSpine({
    required this.accountScopeId,
    required this.updatedAt,
    List<PersonContextSignal> signals = const <PersonContextSignal>[],
  }) : signals = List<PersonContextSignal>.unmodifiable(signals) {
    validate();
  }

  static const int schemaVersion = 1;
  static const int maxSignals = 200;

  final String accountScopeId;
  final DateTime updatedAt;
  final List<PersonContextSignal> signals;

  factory PersonContextSpine.empty(String accountScopeId, DateTime now) {
    return PersonContextSpine(
      accountScopeId: accountScopeId,
      updatedAt: now.toUtc(),
    );
  }

  PersonContextView forSurface(PersonContextSurface surface, DateTime now) {
    final List<PersonContextSignal> available = signals
        .where((signal) => signal.isAvailableTo(surface, now))
        .toList(growable: false);
    final Set<PersonContextKind> knownKinds = available
        .map((signal) => signal.kind)
        .toSet();
    return PersonContextView(
      accountScopeId: accountScopeId,
      surface: surface,
      observedAt: now.toUtc(),
      signals: available,
      unknownKinds: PersonContextKind.values.toSet().difference(knownKinds),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'accountScopeId': accountScopeId,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'signals': signals.map((signal) => signal.toJson()).toList(),
  };

  Map<String, dynamic> toExportJson(DateTime exportedAt) => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'signals': signals
        .where(
          (signal) =>
              signal.exportBehavior == PersonContextExportBehavior.include,
        )
        .map((signal) => signal.toJson())
        .toList(),
  };

  factory PersonContextSpine.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported person context schema.');
    }
    return PersonContextSpine(
      accountScopeId: _requiredString(json, 'accountScopeId'),
      updatedAt: _requiredDate(json, 'updatedAt'),
      signals: _requiredList(json, 'signals')
          .map(
            (dynamic value) =>
                PersonContextSignal.fromJson(_stringMap(value, 'signals')),
          )
          .toList(growable: false),
    );
  }

  void validate() {
    if (accountScopeId.trim().isEmpty ||
        accountScopeId != accountScopeId.trim()) {
      throw StateError('Person context requires an exact account scope.');
    }
    if (signals.length > maxSignals) {
      throw StateError('Person context signal count is unbounded.');
    }
    final Set<String> ids = <String>{};
    for (final PersonContextSignal signal in signals) {
      signal.validate();
      if (signal.recordedAt.toUtc().isAfter(updatedAt.toUtc())) {
        throw StateError('Person context update time precedes a signal.');
      }
      if (!ids.add(signal.id)) {
        throw StateError('Person context signal ids must be unique.');
      }
    }
  }
}

final class PersonContextView {
  PersonContextView({
    required this.accountScopeId,
    required this.surface,
    required this.observedAt,
    required List<PersonContextSignal> signals,
    required Set<PersonContextKind> unknownKinds,
  }) : signals = List<PersonContextSignal>.unmodifiable(signals),
       unknownKinds = Set<PersonContextKind>.unmodifiable(unknownKinds);

  final String accountScopeId;
  final PersonContextSurface surface;
  final DateTime observedAt;
  final List<PersonContextSignal> signals;
  final Set<PersonContextKind> unknownKinds;

  bool get isEmpty => signals.isEmpty;
}

Never _invalid(String field) =>
    throw FormatException('Invalid person context field: $field.');

Map<String, dynamic> _stringMap(dynamic value, String field) {
  if (value is! Map<dynamic, dynamic>) _invalid(field);
  if (value.keys.any((dynamic key) => key is! String)) _invalid(field);
  return value.cast<String, dynamic>();
}

String _requiredString(Map<String, dynamic> json, String field) {
  final dynamic value = json[field];
  if (value is! String || value.trim().isEmpty) _invalid(field);
  return value;
}

List<dynamic> _requiredList(Map<String, dynamic> json, String field) {
  final dynamic value = json[field];
  if (value is! List<dynamic>) _invalid(field);
  return value;
}

DateTime _requiredDate(Map<String, dynamic> json, String field) {
  final dynamic value = json[field];
  if (value is! String) _invalid(field);
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) _invalid(field);
  return parsed.toUtc();
}

DateTime? _optionalDate(Map<String, dynamic> json, String field) {
  final dynamic value = json[field];
  if (value == null) return null;
  if (value is! String) _invalid(field);
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) _invalid(field);
  return parsed.toUtc();
}

T _requiredEnum<T extends Enum>(
  Map<String, dynamic> json,
  String field,
  List<T> values,
) => _enumFromString(json[field], field, values);

T _enumFromString<T extends Enum>(dynamic raw, String field, List<T> values) {
  if (raw is! String) _invalid(field);
  for (final T value in values) {
    if (value.name == raw) return value;
  }
  return _invalid(field);
}
