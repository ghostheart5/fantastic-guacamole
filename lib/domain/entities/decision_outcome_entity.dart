/// CHRONOSPARK-CLASS: SHIPPING | Feature: Decision outcomes
enum DecisionOutcomeKind {
  shown,
  accepted,
  rejected,
  corrected,
  completed,
  skipped,
  deferred,
}

/// Bounded evidence connecting one recommendation to what the user did next.
class DecisionOutcomeEntity {
  const DecisionOutcomeEntity({
    required this.decisionId,
    required this.kind,
    required this.surface,
    required this.recordedAt,
    required this.modelVersion,
    required this.recommendationConfidence,
    this.subjectId,
    this.detail,
  });

  final String decisionId;
  final DecisionOutcomeKind kind;
  final String surface;
  final DateTime recordedAt;
  final String modelVersion;
  final double recommendationConfidence;
  final String? subjectId;
  final String? detail;

  String get id => '$decisionId::${kind.name}::$surface';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'decisionId': decisionId,
    'kind': kind.name,
    'surface': surface,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'modelVersion': modelVersion,
    'recommendationConfidence': recommendationConfidence,
    'subjectId': subjectId,
    'detail': detail,
  };

  factory DecisionOutcomeEntity.fromJson(Map<String, dynamic> json) =>
      DecisionOutcomeEntity(
        decisionId: json['decisionId']?.toString() ?? '',
        kind: DecisionOutcomeKind.values.firstWhere(
          (DecisionOutcomeKind value) => value.name == json['kind'],
          orElse: () => DecisionOutcomeKind.shown,
        ),
        surface: json['surface']?.toString() ?? 'unknown',
        recordedAt:
            DateTime.tryParse(json['recordedAt']?.toString() ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        modelVersion: json['modelVersion']?.toString() ?? 'unknown',
        recommendationConfidence:
            ((json['recommendationConfidence'] as num?)?.toDouble() ?? 0).clamp(
              0.0,
              1.0,
            ),
        subjectId: json['subjectId']?.toString(),
        detail: json['detail']?.toString(),
      );
}
