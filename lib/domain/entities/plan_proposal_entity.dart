import 'package:fantastic_guacamole/domain/entities/time_block.dart';

enum PlanProposalStatus { preview, applied, rejected }

class PlanConflict {
  const PlanConflict({
    required this.firstBlockId,
    required this.secondBlockId,
    required this.reason,
  });

  final String firstBlockId;
  final String secondBlockId;
  final String reason;

  void validate() {
    if (firstBlockId.trim().isEmpty ||
        firstBlockId != firstBlockId.trim() ||
        secondBlockId.trim().isEmpty ||
        secondBlockId != secondBlockId.trim() ||
        firstBlockId == secondBlockId ||
        reason.trim().isEmpty ||
        reason != reason.trim()) {
      throw const FormatException('Plan proposal conflict is invalid.');
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'firstBlockId': firstBlockId,
    'secondBlockId': secondBlockId,
    'reason': reason,
  };

  factory PlanConflict.fromJson(Map<String, Object?> json) {
    const Set<String> expected = <String>{
      'firstBlockId',
      'secondBlockId',
      'reason',
    };
    final Set<String> keys = json.keys.toSet();
    if (keys.difference(expected).isNotEmpty ||
        expected.difference(keys).isNotEmpty ||
        json['firstBlockId'] is! String ||
        json['secondBlockId'] is! String ||
        json['reason'] is! String) {
      throw const FormatException('Invalid plan proposal conflict shape.');
    }
    final PlanConflict conflict = PlanConflict(
      firstBlockId: json['firstBlockId']! as String,
      secondBlockId: json['secondBlockId']! as String,
      reason: json['reason']! as String,
    );
    conflict.validate();
    return conflict;
  }
}

class PlanProposalEntity {
  PlanProposalEntity({
    this.schemaVersion = currentSchemaVersion,
    required this.id,
    required DateTime date,
    required List<TimeBlock> blocks,
    required DateTime generatedAt,
    this.status = PlanProposalStatus.preview,
    List<PlanConflict> conflicts = const <PlanConflict>[],
    List<String> evidenceSources = const <String>[],
    this.sourceDecisionId,
    this.rejectionReason,
    DateTime? resolvedAt,
  }) : date = date.toUtc(),
       blocks = List<TimeBlock>.unmodifiable(blocks),
       generatedAt = generatedAt.toUtc(),
       conflicts = List<PlanConflict>.unmodifiable(conflicts),
       evidenceSources = List<String>.unmodifiable(evidenceSources),
       resolvedAt = resolvedAt?.toUtc();

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final DateTime date;
  final List<TimeBlock> blocks;
  final DateTime generatedAt;
  final PlanProposalStatus status;
  final List<PlanConflict> conflicts;
  final List<String> evidenceSources;
  final String? sourceDecisionId;
  final String? rejectionReason;
  final DateTime? resolvedAt;

  bool get isFeasible =>
      conflicts.isEmpty && blocks.every((TimeBlock block) => block.validate());

  void validate() {
    if (schemaVersion != currentSchemaVersion) {
      throw const FormatException('Unsupported plan proposal schema version.');
    }
    if (id.trim().isEmpty || id != id.trim()) {
      throw const FormatException('Plan proposals require a normalized id.');
    }
    if (generatedAt.year < 2020) {
      throw const FormatException('Plan proposal generation time is invalid.');
    }
    final Set<String> blockIds = <String>{};
    for (final TimeBlock block in blocks) {
      if (block.id.trim().isEmpty ||
          block.taskId.trim().isEmpty ||
          block.title.trim().isEmpty ||
          !block.validate()) {
        throw const FormatException('Plan proposal contains an invalid block.');
      }
      if (!blockIds.add(block.id)) {
        throw const FormatException('Plan proposal block ids must be unique.');
      }
    }
    for (final PlanConflict conflict in conflicts) {
      conflict.validate();
      if (!blockIds.contains(conflict.firstBlockId) ||
          !blockIds.contains(conflict.secondBlockId)) {
        throw const FormatException('Plan proposal conflict is invalid.');
      }
    }
    final List<String> normalizedSources = evidenceSources
        .map((String value) => value.trim())
        .toList(growable: false);
    if (normalizedSources.any((String value) => value.isEmpty) ||
        normalizedSources.toSet().length != normalizedSources.length) {
      throw const FormatException(
        'Plan proposal evidence sources must be non-empty and unique.',
      );
    }
    if (status == PlanProposalStatus.preview && resolvedAt != null) {
      throw const FormatException('Preview proposals cannot be resolved.');
    }
    if (status != PlanProposalStatus.preview && resolvedAt == null) {
      throw const FormatException(
        'Resolved proposals require a resolution time.',
      );
    }
    if (status != PlanProposalStatus.rejected && rejectionReason != null) {
      throw const FormatException(
        'Only rejected proposals can include a rejection reason.',
      );
    }
    if (rejectionReason != null &&
        (rejectionReason!.trim().isEmpty ||
            rejectionReason != rejectionReason!.trim())) {
      throw const FormatException(
        'Plan proposal rejection reasons must be normalized.',
      );
    }
    if (sourceDecisionId != null &&
        (sourceDecisionId!.trim().isEmpty ||
            sourceDecisionId != sourceDecisionId!.trim())) {
      throw const FormatException(
        'Plan proposal source decision ids must be normalized.',
      );
    }
  }

  PlanProposalEntity copyWith({
    PlanProposalStatus? status,
    String? rejectionReason,
    DateTime? resolvedAt,
  }) {
    return PlanProposalEntity(
      schemaVersion: schemaVersion,
      id: id,
      date: date,
      blocks: blocks,
      generatedAt: generatedAt,
      status: status ?? this.status,
      conflicts: conflicts,
      evidenceSources: evidenceSources,
      sourceDecisionId: sourceDecisionId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'id': id,
    'date': date.toUtc().toIso8601String(),
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'status': status.name,
    'blocks': blocks
        .map(
          (TimeBlock block) => <String, Object?>{
            'id': block.id,
            'taskId': block.taskId,
            'title': block.title,
            'description': block.description,
            'start': block.start.toUtc().toIso8601String(),
            'end': block.end.toUtc().toIso8601String(),
            'completed': block.completed,
          },
        )
        .toList(growable: false),
    'conflicts': conflicts
        .map((PlanConflict conflict) => conflict.toJson())
        .toList(growable: false),
    'evidenceSources': evidenceSources,
    'sourceDecisionId': sourceDecisionId,
    'rejectionReason': rejectionReason,
    'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
  };

  factory PlanProposalEntity.fromJson(Map<String, Object?> json) {
    const Set<String> expected = <String>{
      'schemaVersion',
      'id',
      'date',
      'generatedAt',
      'status',
      'blocks',
      'conflicts',
      'evidenceSources',
      'sourceDecisionId',
      'rejectionReason',
      'resolvedAt',
    };
    if (json.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException('Invalid plan proposal schema shape.');
    }
    final Object? schemaVersion = json['schemaVersion'];
    final Object? id = json['id'];
    final Object? rawDate = json['date'];
    final Object? rawGeneratedAt = json['generatedAt'];
    final DateTime? date = rawDate is String
        ? DateTime.tryParse(rawDate)
        : null;
    final DateTime? generatedAt = rawGeneratedAt is String
        ? DateTime.tryParse(rawGeneratedAt)
        : null;
    final Object? rawStatus = json['status'];
    final Object? rawBlocks = json['blocks'];
    final Object? rawConflicts = json['conflicts'];
    final Object? rawEvidence = json['evidenceSources'];
    if (schemaVersion is! int ||
        id is! String ||
        date == null ||
        generatedAt == null ||
        rawStatus is! String ||
        rawBlocks is! List<Object?> ||
        rawConflicts is! List<Object?> ||
        rawEvidence is! List<Object?>) {
      throw const FormatException('Invalid plan proposal schema value.');
    }
    PlanProposalStatus? parsedStatus;
    for (final PlanProposalStatus value in PlanProposalStatus.values) {
      if (value.name == rawStatus) parsedStatus = value;
    }
    if (parsedStatus == null) {
      throw const FormatException('Unknown plan proposal status.');
    }
    final PlanProposalEntity proposal = PlanProposalEntity(
      schemaVersion: schemaVersion,
      id: id,
      date: date.toUtc(),
      generatedAt: generatedAt.toUtc(),
      status: parsedStatus,
      blocks: rawBlocks
          .map((Object? raw) {
            if (raw is! Map<Object?, Object?>) {
              throw const FormatException('Invalid plan proposal block.');
            }
            final Map<String, Object?> block = Map<String, Object?>.from(raw);
            const Set<String> blockKeys = <String>{
              'id',
              'taskId',
              'title',
              'description',
              'start',
              'end',
              'completed',
            };
            if (block.keys.toSet().difference(blockKeys).isNotEmpty ||
                blockKeys.difference(block.keys.toSet()).isNotEmpty) {
              throw const FormatException('Invalid plan proposal block shape.');
            }
            final Object? rawId = block['id'];
            final Object? rawTaskId = block['taskId'];
            final Object? rawTitle = block['title'];
            final Object? rawDescription = block['description'];
            final Object? rawStart = block['start'];
            final Object? rawEnd = block['end'];
            final DateTime? start = rawStart is String
                ? DateTime.tryParse(rawStart)
                : null;
            final DateTime? end = rawEnd is String
                ? DateTime.tryParse(rawEnd)
                : null;
            if (rawId is! String ||
                rawTaskId is! String ||
                rawTitle is! String ||
                rawDescription != null && rawDescription is! String ||
                start == null ||
                end == null ||
                block['completed'] is! bool) {
              throw const FormatException('Invalid plan proposal block value.');
            }
            return TimeBlock(
              id: rawId,
              taskId: rawTaskId,
              title: rawTitle,
              description: rawDescription as String?,
              start: start.toUtc(),
              end: end.toUtc(),
              completed: block['completed']! as bool,
            );
          })
          .toList(growable: false),
      conflicts: rawConflicts
          .map((Object? raw) {
            if (raw is! Map<Object?, Object?>) {
              throw const FormatException('Invalid plan proposal conflict.');
            }
            return PlanConflict.fromJson(Map<String, Object?>.from(raw));
          })
          .toList(growable: false),
      evidenceSources: rawEvidence
          .map((Object? raw) {
            if (raw is! String) {
              throw const FormatException(
                'Invalid plan proposal evidence source.',
              );
            }
            return raw;
          })
          .toList(growable: false),
      sourceDecisionId: _optionalStrictString(json, 'sourceDecisionId'),
      rejectionReason: _optionalStrictString(json, 'rejectionReason'),
      resolvedAt: _optionalStrictDateTime(json, 'resolvedAt'),
    );
    proposal.validate();
    return proposal;
  }
}

String? _optionalStrictString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$key must be null or a string.');
  }
  return value;
}

DateTime? _optionalStrictDateTime(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('$key must be null or an ISO-8601 string.');
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$key is not a valid ISO-8601 time.');
  }
  return parsed.toUtc();
}
