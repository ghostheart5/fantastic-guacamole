import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';

enum SIResponseOrigin {
  operatingSystem,
  localDeterministic,
  localFallback,
  remoteProxy,
  unavailable,
}

enum SIProcessingMode { localOnly, remoteWithRecentConversation, unavailable }

enum SIDecisionDisposition {
  presented,
  accepted,
  deferred,
  rejected,
  executed,
  superseded,
}

/// Versioned, user-inspectable metadata for one consequential SI response.
///
/// The receipt deliberately contains summarized evidence rather than raw logs,
/// prompts, tokens, or backend diagnostics. It is safe to persist only in the
/// app's protected, account-scoped intelligence store.
class SIIntelligenceReceipt {
  SIIntelligenceReceipt({
    required this.decisionId,
    required this.rationale,
    required this.whyItMatters,
    required this.generatedAt,
    required this.expiresAt,
    required this.confidence,
    required this.confidenceScore,
    required this.evidence,
    required this.sourceRevisions,
    required this.modelVersion,
    required this.origin,
    required this.processingMode,
    this.consequenceOfDelay = '',
    this.assumptions = const <String>[],
    this.warnings = const <String>[],
    this.limitations = const <String>[],
    this.actionIntent,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String decisionId;
  final String rationale;
  final String whyItMatters;
  final String consequenceOfDelay;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final OperatingConfidence confidence;
  final double confidenceScore;
  final List<OperatingEvidence> evidence;
  final Map<String, String> sourceRevisions;
  final String modelVersion;
  final SIResponseOrigin origin;
  final SIProcessingMode processingMode;
  final List<String> assumptions;
  final List<String> warnings;
  final List<String> limitations;
  final OperatingActionIntent? actionIntent;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());

  String get processingLabel => switch (processingMode) {
    SIProcessingMode.localOnly => 'Processed on this device',
    SIProcessingMode.remoteWithRecentConversation =>
      'Cloud AI received this prompt and limited recent conversation',
    SIProcessingMode.unavailable => 'Processing origin unavailable',
  };

  void validate() {
    if (schemaVersion != currentSchemaVersion) {
      throw StateError('Unsupported SI intelligence receipt version.');
    }
    if (decisionId.trim().isEmpty || rationale.trim().isEmpty) {
      throw StateError('SI intelligence receipts require an id and rationale.');
    }
    if (!expiresAt.isAfter(generatedAt)) {
      throw StateError('SI intelligence receipts require a future expiry.');
    }
    if (confidenceScore.isNaN ||
        confidenceScore < 0 ||
        confidenceScore > 1) {
      throw StateError('SI confidence must be between zero and one.');
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'decisionId': decisionId,
    'rationale': rationale,
    'whyItMatters': whyItMatters,
    'consequenceOfDelay': consequenceOfDelay,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'confidence': confidence.name,
    'confidenceScore': confidenceScore,
    'evidence': evidence
        .map((OperatingEvidence item) => item.toJson())
        .toList(growable: false),
    'sourceRevisions': sourceRevisions,
    'modelVersion': modelVersion,
    'origin': origin.name,
    'processingMode': processingMode.name,
    'assumptions': assumptions,
    'warnings': warnings,
    'limitations': limitations,
    'actionIntent': actionIntent?.toJson(),
  };

  factory SIIntelligenceReceipt.fromJson(Map<String, dynamic> json) {
    final int version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version != currentSchemaVersion) {
      throw const FormatException(
        'Unsupported SI intelligence receipt version.',
      );
    }
    final DateTime? generatedAt = DateTime.tryParse(
      json['generatedAt']?.toString() ?? '',
    );
    final DateTime? expiresAt = DateTime.tryParse(
      json['expiresAt']?.toString() ?? '',
    );
    if (generatedAt == null || expiresAt == null) {
      throw const FormatException('Invalid SI intelligence receipt time.');
    }
    final Object? action = json['actionIntent'];
    final SIIntelligenceReceipt receipt = SIIntelligenceReceipt(
      schemaVersion: version,
      decisionId: json['decisionId']?.toString() ?? '',
      rationale: json['rationale']?.toString() ?? '',
      whyItMatters: json['whyItMatters']?.toString() ?? '',
      consequenceOfDelay: json['consequenceOfDelay']?.toString() ?? '',
      generatedAt: generatedAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
      confidence: OperatingConfidence.values.firstWhere(
        (OperatingConfidence value) =>
            value.name == json['confidence']?.toString(),
        orElse: () => OperatingConfidence.insufficientEvidence,
      ),
      confidenceScore: (json['confidenceScore'] as num?)
              ?.toDouble()
              .clamp(0.0, 1.0)
              .toDouble() ??
          0,
      evidence: (json['evidence'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> item) => OperatingEvidence.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      sourceRevisions: Map<String, String>.from(
        json['sourceRevisions'] as Map? ?? const <String, String>{},
      ),
      modelVersion: json['modelVersion']?.toString() ?? 'unknown',
      origin: SIResponseOrigin.values.firstWhere(
        (SIResponseOrigin value) => value.name == json['origin']?.toString(),
        orElse: () => SIResponseOrigin.unavailable,
      ),
      processingMode: SIProcessingMode.values.firstWhere(
        (SIProcessingMode value) =>
            value.name == json['processingMode']?.toString(),
        orElse: () => SIProcessingMode.unavailable,
      ),
      assumptions: _stringList(json['assumptions']),
      warnings: _stringList(json['warnings']),
      limitations: _stringList(json['limitations']),
      actionIntent: action is Map<Object?, Object?>
          ? OperatingActionIntent.fromJson(Map<String, dynamic>.from(action))
          : null,
    );
    receipt.validate();
    return receipt;
  }

  factory SIIntelligenceReceipt.fromOperatingDecision(
    OperatingDecisionReceipt decision, {
    double? confidenceScore,
  }) {
    final double score = confidenceScore ?? switch (decision.confidence) {
      OperatingConfidence.high => .85,
      OperatingConfidence.moderate => .65,
      OperatingConfidence.low => .4,
      OperatingConfidence.insufficientEvidence => .15,
    };
    final SIIntelligenceReceipt receipt = SIIntelligenceReceipt(
      decisionId: decision.decisionId,
      rationale: decision.rationale,
      whyItMatters: decision.whyItMatters,
      consequenceOfDelay: decision.consequenceOfDelay,
      generatedAt: decision.generatedAt,
      expiresAt: decision.expiresAt,
      confidence: decision.confidence,
      confidenceScore: score,
      evidence: decision.evidence,
      sourceRevisions: decision.sourceRevisions,
      modelVersion: decision.modelVersion,
      origin: SIResponseOrigin.operatingSystem,
      processingMode: SIProcessingMode.localOnly,
      assumptions: decision.assumptions,
      warnings: decision.warnings,
      limitations: const <String>[
        'Decision support is not a guaranteed outcome.',
      ],
      actionIntent: decision.actionIntent,
    );
    receipt.validate();
    return receipt;
  }
}

class SIDecisionLedgerEntry {
  const SIDecisionLedgerEntry({
    required this.receipt,
    required this.disposition,
    required this.updatedAt,
    this.outcomeSummary,
  });

  final SIIntelligenceReceipt receipt;
  final SIDecisionDisposition disposition;
  final DateTime updatedAt;
  final String? outcomeSummary;

  SIDecisionLedgerEntry copyWith({
    SIDecisionDisposition? disposition,
    DateTime? updatedAt,
    String? outcomeSummary,
  }) => SIDecisionLedgerEntry(
    receipt: receipt,
    disposition: disposition ?? this.disposition,
    updatedAt: updatedAt ?? this.updatedAt,
    outcomeSummary: outcomeSummary ?? this.outcomeSummary,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'receipt': receipt.toJson(),
    'disposition': disposition.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'outcomeSummary': outcomeSummary,
  };

  factory SIDecisionLedgerEntry.fromJson(Map<String, dynamic> json) =>
      SIDecisionLedgerEntry(
        receipt: SIIntelligenceReceipt.fromJson(
          Map<String, dynamic>.from(json['receipt'] as Map),
        ),
        disposition: SIDecisionDisposition.values.firstWhere(
          (SIDecisionDisposition value) =>
              value.name == json['disposition']?.toString(),
          orElse: () => SIDecisionDisposition.presented,
        ),
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        outcomeSummary: json['outcomeSummary']?.toString(),
      );
}

List<String> _stringList(Object? value) =>
    (value as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic item) => item.toString())
        .where((String item) => item.trim().isNotEmpty)
        .toList(growable: false);
