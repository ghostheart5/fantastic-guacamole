import 'dart:convert';

import 'package:crypto/crypto.dart';

enum OperatingEvidenceKind {
  observed,
  derived,
  estimated,
  predicted,
  heuristic,
  userProvided,
  unavailable,
}

enum OperatingConfidence { high, moderate, low, insufficientEvidence }

enum OperatingChangeKind {
  priority,
  schedule,
  momentum,
  progression,
  risk,
  evidence,
}

enum OperatingActionType {
  openEntity,
  openCreator,
  openTimeline,
  openSmartPlanner,
  openSiConsole,
  openTrajectoryEngine,
  openProgression,
  createTimelineBlock,
  rescheduleCommitment,
  reprioritizeGoal,
  acknowledgeDecision,
  none,
}

class OperatingEvidence {
  const OperatingEvidence({
    required this.code,
    required this.description,
    required this.kind,
    required this.recordedAt,
    required this.source,
    this.subjectId,
    this.freshUntil,
    this.weight,
  });

  final String code;
  final String description;
  final OperatingEvidenceKind kind;
  final DateTime recordedAt;
  final String source;
  final String? subjectId;
  final DateTime? freshUntil;
  final double? weight;

  bool get isFresh => freshUntil == null || freshUntil!.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'description': description,
    'kind': kind.name,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'source': source,
    'subjectId': subjectId,
    'freshUntil': freshUntil?.toUtc().toIso8601String(),
    'weight': weight,
  };

  factory OperatingEvidence.fromJson(Map<String, dynamic> json) =>
      OperatingEvidence(
        code: json['code']?.toString() ?? 'unknown',
        description: json['description']?.toString() ?? 'Evidence unavailable.',
        kind: OperatingEvidenceKind.values.firstWhere(
          (OperatingEvidenceKind value) => value.name == json['kind'],
          orElse: () => OperatingEvidenceKind.unavailable,
        ),
        recordedAt:
            DateTime.tryParse(json['recordedAt']?.toString() ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        source: json['source']?.toString() ?? 'unknown',
        subjectId: json['subjectId']?.toString(),
        freshUntil: DateTime.tryParse(
          json['freshUntil']?.toString() ?? '',
        )?.toUtc(),
        weight: (json['weight'] as num?)?.toDouble(),
      );
}

class OperatingActionIntent {
  const OperatingActionIntent({
    required this.id,
    required this.type,
    required this.label,
    required this.destination,
    this.targetEntityId,
    this.parameters = const <String, dynamic>{},
    this.requiresConfirmation = false,
    this.reversible = true,
  });

  final String id;
  final OperatingActionType type;
  final String label;
  final String destination;
  final String? targetEntityId;
  final Map<String, dynamic> parameters;
  final bool requiresConfirmation;
  final bool reversible;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.name,
    'label': label,
    'destination': destination,
    'targetEntityId': targetEntityId,
    'parameters': parameters,
    'requiresConfirmation': requiresConfirmation,
    'reversible': reversible,
  };

  factory OperatingActionIntent.fromJson(Map<String, dynamic> json) =>
      OperatingActionIntent(
        id: json['id']?.toString() ?? 'action-unknown',
        type: OperatingActionType.values.firstWhere(
          (OperatingActionType value) => value.name == json['type'],
          orElse: () => OperatingActionType.none,
        ),
        label: json['label']?.toString() ?? 'Review recommendation',
        destination: json['destination']?.toString() ?? '/nexus',
        targetEntityId: json['targetEntityId']?.toString(),
        parameters: Map<String, dynamic>.from(
          json['parameters'] as Map? ?? const <String, dynamic>{},
        ),
        requiresConfirmation: json['requiresConfirmation'] == true,
        reversible: json['reversible'] != false,
      );
}

class OperatingSnapshot {
  OperatingSnapshot({
    required this.accountScope,
    required this.observedAt,
    required this.sourceRevisions,
    required this.activeGoalCount,
    required this.actionableCount,
    required this.overdueCount,
    required this.completedToday,
    required this.energy,
    required this.fatigue,
    required this.momentum,
    required this.pressure,
    required this.topActionId,
    required this.topActionLabel,
    required this.activeRisks,
    required this.evidenceCoverage,
    String? snapshotId,
    this.schemaVersion = currentSchemaVersion,
  }) : snapshotId =
           snapshotId ??
           stableId(<String, dynamic>{
             'scope': accountScope,
             'sources': sourceRevisions,
             'goals': activeGoalCount,
             'actions': actionableCount,
             'overdue': overdueCount,
             'completedToday': completedToday,
             'energy': energy,
             'fatigue': fatigue,
             'momentum': momentum,
             'pressure': pressure,
             'topActionId': topActionId,
             'topActionLabel': topActionLabel,
             'risks': activeRisks,
             'coverage': evidenceCoverage,
           });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String snapshotId;
  final String accountScope;
  final DateTime observedAt;
  final Map<String, String> sourceRevisions;
  final int activeGoalCount;
  final int actionableCount;
  final int overdueCount;
  final int completedToday;
  final double energy;
  final double fatigue;
  final int momentum;
  final int pressure;
  final String? topActionId;
  final String topActionLabel;
  final List<String> activeRisks;
  final double evidenceCoverage;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'snapshotId': snapshotId,
    'accountScope': accountScope,
    'observedAt': observedAt.toUtc().toIso8601String(),
    'sourceRevisions': sourceRevisions,
    'activeGoalCount': activeGoalCount,
    'actionableCount': actionableCount,
    'overdueCount': overdueCount,
    'completedToday': completedToday,
    'energy': energy,
    'fatigue': fatigue,
    'momentum': momentum,
    'pressure': pressure,
    'topActionId': topActionId,
    'topActionLabel': topActionLabel,
    'activeRisks': activeRisks,
    'evidenceCoverage': evidenceCoverage,
  };

  factory OperatingSnapshot.fromJson(Map<String, dynamic> json) {
    final int version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version != currentSchemaVersion) {
      throw FormatException('Unsupported decision snapshot version $version.');
    }
    return OperatingSnapshot(
      schemaVersion: version,
      snapshotId: json['snapshotId']?.toString(),
      accountScope: json['accountScope']?.toString() ?? '',
      observedAt:
          DateTime.tryParse(json['observedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sourceRevisions: Map<String, String>.from(
        json['sourceRevisions'] as Map? ?? const <String, String>{},
      ),
      activeGoalCount: (json['activeGoalCount'] as num?)?.toInt() ?? 0,
      actionableCount: (json['actionableCount'] as num?)?.toInt() ?? 0,
      overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
      completedToday: (json['completedToday'] as num?)?.toInt() ?? 0,
      energy: (json['energy'] as num?)?.toDouble() ?? 0,
      fatigue: (json['fatigue'] as num?)?.toDouble() ?? 0,
      momentum: (json['momentum'] as num?)?.toInt() ?? 0,
      pressure: (json['pressure'] as num?)?.toInt() ?? 0,
      topActionId: json['topActionId']?.toString(),
      topActionLabel: json['topActionLabel']?.toString() ?? 'No action ranked',
      activeRisks: (json['activeRisks'] as List? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      evidenceCoverage: (json['evidenceCoverage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OperatingChange {
  const OperatingChange({
    required this.kind,
    required this.label,
    required this.previousValue,
    required this.currentValue,
    required this.reason,
    required this.material,
  });

  final OperatingChangeKind kind;
  final String label;
  final String previousValue;
  final String currentValue;
  final String reason;
  final bool material;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'label': label,
    'previousValue': previousValue,
    'currentValue': currentValue,
    'reason': reason,
    'material': material,
  };
}

class OperatingDelta {
  const OperatingDelta({
    required this.previousSnapshotId,
    required this.currentSnapshotId,
    required this.comparedAt,
    required this.changes,
    required this.summary,
    required this.isBaseline,
  });

  final String? previousSnapshotId;
  final String currentSnapshotId;
  final DateTime comparedAt;
  final List<OperatingChange> changes;
  final String summary;
  final bool isBaseline;

  List<OperatingChange> get materialChanges =>
      changes.where((OperatingChange item) => item.material).toList();
}

class OperatingDecisionReceipt {
  OperatingDecisionReceipt({
    required this.subjectId,
    required this.recommendedAction,
    required this.rationale,
    required this.whyItMatters,
    required this.consequenceOfDelay,
    required this.generatedAt,
    required this.expiresAt,
    required this.confidence,
    double? recommendationConfidence,
    required this.evidence,
    required this.actionIntent,
    required this.sourceRevisions,
    required this.modelVersion,
    this.assumptions = const <String>[],
    this.warnings = const <String>[],
    String? decisionId,
  }) : recommendationConfidence =
           (recommendationConfidence ?? _defaultConfidence(confidence)).clamp(
             0.0,
             .99,
           ).toDouble(),
       decisionId =
           decisionId ??
           stableId(<String, dynamic>{
             'subjectId': subjectId,
             'action': recommendedAction,
             'rationale': rationale,
             'sources': sourceRevisions,
             'modelVersion': modelVersion,
           });

  final String decisionId;
  final String? subjectId;
  final String recommendedAction;
  final String rationale;
  final String whyItMatters;
  final String consequenceOfDelay;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final OperatingConfidence confidence;
  final double recommendationConfidence;
  final List<OperatingEvidence> evidence;
  final OperatingActionIntent actionIntent;
  final Map<String, String> sourceRevisions;
  final String modelVersion;
  final List<String> assumptions;
  final List<String> warnings;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());

  void validate() {
    if (recommendedAction.trim().isEmpty || rationale.trim().isEmpty) {
      throw StateError('A decision needs one action and its reason.');
    }
    if (!expiresAt.isAfter(generatedAt)) {
      throw StateError('A decision must expire after generation.');
    }
    if (actionIntent.targetEntityId != null &&
        subjectId != null &&
        actionIntent.targetEntityId != subjectId) {
      throw StateError('Action intent and decision subject must match.');
    }
  }
}

double _defaultConfidence(OperatingConfidence confidence) =>
    switch (confidence) {
      OperatingConfidence.high => .82,
      OperatingConfidence.moderate => .64,
      OperatingConfidence.low => .38,
      OperatingConfidence.insufficientEvidence => .15,
    };

class DecisionIntelligence {
  const DecisionIntelligence({
    required this.snapshot,
    required this.delta,
    required this.decision,
    required this.acknowledgedSnapshotId,
  });

  final OperatingSnapshot snapshot;
  final OperatingDelta delta;
  final OperatingDecisionReceipt decision;
  final String? acknowledgedSnapshotId;

  bool get hasUnacknowledgedChange =>
      acknowledgedSnapshotId != snapshot.snapshotId &&
      delta.materialChanges.isNotEmpty;
}

class OperatingDeltaEngine {
  const OperatingDeltaEngine();

  OperatingDelta compare({
    required OperatingSnapshot? previous,
    required OperatingSnapshot current,
    DateTime? comparedAt,
  }) {
    final DateTime now = (comparedAt ?? DateTime.now()).toUtc();
    if (previous == null) {
      return OperatingDelta(
        previousSnapshotId: null,
        currentSnapshotId: current.snapshotId,
        comparedAt: now,
        changes: const <OperatingChange>[],
        summary:
            'Baseline established. Future updates will show material changes.',
        isBaseline: true,
      );
    }
    if (previous.snapshotId == current.snapshotId) {
      return OperatingDelta(
        previousSnapshotId: previous.snapshotId,
        currentSnapshotId: current.snapshotId,
        comparedAt: now,
        changes: const <OperatingChange>[],
        summary: 'No material decision changes since the last checkpoint.',
        isBaseline: false,
      );
    }

    final List<OperatingChange> changes = <OperatingChange>[];
    void add(
      OperatingChangeKind kind,
      String label,
      Object before,
      Object after,
      String reason,
      bool material,
    ) {
      if (before == after) return;
      changes.add(
        OperatingChange(
          kind: kind,
          label: label,
          previousValue: '$before',
          currentValue: '$after',
          reason: reason,
          material: material,
        ),
      );
    }

    add(
      OperatingChangeKind.priority,
      'Top action',
      previous.topActionLabel,
      current.topActionLabel,
      'The current ranking changed after task, schedule, or state signals changed.',
      true,
    );
    add(
      OperatingChangeKind.schedule,
      'Overdue commitments',
      previous.overdueCount,
      current.overdueCount,
      'Timeline due-state changed.',
      true,
    );
    add(
      OperatingChangeKind.momentum,
      'Momentum',
      previous.momentum,
      current.momentum,
      'Recent execution and energy signals changed.',
      (current.momentum - previous.momentum).abs() >= 5,
    );
    add(
      OperatingChangeKind.risk,
      'Pressure',
      previous.pressure,
      current.pressure,
      'Current load and recovery pressure changed.',
      (current.pressure - previous.pressure).abs() >= 5,
    );
    add(
      OperatingChangeKind.progression,
      'Completed today',
      previous.completedToday,
      current.completedToday,
      'A completion was recorded in the current day.',
      true,
    );
    add(
      OperatingChangeKind.evidence,
      'Evidence coverage',
      (previous.evidenceCoverage * 100).round(),
      (current.evidenceCoverage * 100).round(),
      'The availability of decision inputs changed.',
      (current.evidenceCoverage - previous.evidenceCoverage).abs() >= .15,
    );

    final int materialCount = changes.where((item) => item.material).length;
    final String summary = materialCount == 0
        ? 'Inputs changed, but no material decision change was detected.'
        : '$materialCount material change${materialCount == 1 ? '' : 's'} detected since the last checkpoint.';
    return OperatingDelta(
      previousSnapshotId: previous.snapshotId,
      currentSnapshotId: current.snapshotId,
      comparedAt: now,
      changes: List<OperatingChange>.unmodifiable(changes),
      summary: summary,
      isBaseline: false,
    );
  }
}

String stableId(Map<String, dynamic> value) {
  final String canonical = _canonicalJson(value);
  return sha256.convert(utf8.encode(canonical)).toString().substring(0, 24);
}

String _canonicalJson(Object? value) {
  if (value is Map) {
    final List<String> keys = value.keys.map((Object? key) => '$key').toList()
      ..sort();
    return '{${keys.map((String key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}
