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
    this.situation,
    this.optionChosen,
    this.optionSizeMinutes,
    this.deferralReason,
    this.completionResult,
    this.correction,
    this.correctedOutcomeKind,
    this.recommendationHelped,
  });

  final String decisionId;
  final DecisionOutcomeKind kind;
  final String surface;
  final DateTime recordedAt;
  final String modelVersion;
  final double recommendationConfidence;
  final String? subjectId;
  final String? detail;
  final String? situation;
  final String? optionChosen;
  final int? optionSizeMinutes;
  final String? deferralReason;
  final String? completionResult;
  final String? correction;
  final String? correctedOutcomeKind;
  final bool? recommendationHelped;

  DecisionOutcomeEntity copyWith({
    DecisionOutcomeKind? kind,
    DateTime? recordedAt,
    String? detail,
    String? situation,
    String? optionChosen,
    int? optionSizeMinutes,
    String? deferralReason,
    String? completionResult,
    String? correction,
    String? correctedOutcomeKind,
    bool? recommendationHelped,
  }) => DecisionOutcomeEntity(
    decisionId: decisionId,
    kind: kind ?? this.kind,
    surface: surface,
    recordedAt: recordedAt ?? this.recordedAt,
    modelVersion: modelVersion,
    recommendationConfidence: recommendationConfidence,
    subjectId: subjectId,
    detail: detail ?? this.detail,
    situation: situation ?? this.situation,
    optionChosen: optionChosen ?? this.optionChosen,
    optionSizeMinutes: optionSizeMinutes ?? this.optionSizeMinutes,
    deferralReason: deferralReason ?? this.deferralReason,
    completionResult: completionResult ?? this.completionResult,
    correction: correction ?? this.correction,
    correctedOutcomeKind: correctedOutcomeKind ?? this.correctedOutcomeKind,
    recommendationHelped: recommendationHelped ?? this.recommendationHelped,
  );

  String get id {
    final String correctionTarget = kind == DecisionOutcomeKind.corrected
        ? '::${correctedOutcomeKind ?? 'unknown'}'
        : '';
    return '$decisionId::${kind.name}::$surface$correctionTarget';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'decisionId': decisionId,
    'kind': kind.name,
    'surface': surface,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'modelVersion': modelVersion,
    'recommendationConfidence': recommendationConfidence,
    'subjectId': subjectId,
    'detail': detail,
    'situation': situation,
    'optionChosen': optionChosen,
    'optionSizeMinutes': optionSizeMinutes,
    'deferralReason': deferralReason,
    'completionResult': completionResult,
    'correction': correction,
    'correctedOutcomeKind': correctedOutcomeKind,
    'recommendationHelped': recommendationHelped,
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
        situation: json['situation']?.toString(),
        optionChosen: json['optionChosen']?.toString(),
        optionSizeMinutes: (json['optionSizeMinutes'] as num?)?.toInt(),
        deferralReason: json['deferralReason']?.toString(),
        completionResult: json['completionResult']?.toString(),
        correction: json['correction']?.toString(),
        correctedOutcomeKind: json['correctedOutcomeKind']?.toString(),
        recommendationHelped: json['recommendationHelped'] as bool?,
      );
}
