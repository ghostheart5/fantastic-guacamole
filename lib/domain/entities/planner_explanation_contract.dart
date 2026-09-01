// CHRONOSPARK-CLASS: SHIPPING | Feature: Optional Planner explanation
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';

const int plannerExplanationSchemaVersion = 1;
const int plannerExplanationDisclosureVersion = 1;
const String plannerExplanationSurface = 'smart_planner_explanation';

abstract interface class PlannerExplanationPort {
  Future<PlannerExplanationQuote> quote(PlannerExplanationPacket packet);

  Future<PlannerExplanationResult> execute({
    required PlannerExplanationPacket packet,
    required PlannerExplanationQuote quote,
  });
}

final class PlannerExplanationContractException implements Exception {
  const PlannerExplanationContractException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PlannerExplanationContractException($code, $message)';
}

final class PlannerExplanationClause {
  PlannerExplanationClause({required String id, required String text})
    : id = id.trim(),
      text = text.trim() {
    if (!RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(this.id) ||
        this.text.isEmpty ||
        this.text.length > 500) {
      throw const PlannerExplanationContractException(
        'invalid_clause',
        'Explanation clauses require a bounded identifier and visible text.',
      );
    }
  }

  final String id;
  final String text;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'text': text};
}

final class PlannerExplanationPacket {
  PlannerExplanationPacket({required List<PlannerExplanationClause> clauses})
    : clauses = List<PlannerExplanationClause>.unmodifiable(clauses) {
    if (this.clauses.isEmpty || this.clauses.length > 12) {
      throw const PlannerExplanationContractException(
        'invalid_clause_count',
        'An explanation packet requires one to twelve visible clauses.',
      );
    }
    final Set<String> ids = this.clauses
        .map((PlannerExplanationClause item) => item.id)
        .toSet();
    if (ids.length != this.clauses.length) {
      throw const PlannerExplanationContractException(
        'duplicate_clause_id',
        'Explanation clause identifiers must be unique.',
      );
    }
    if (this.clauses.fold<int>(0, (int sum, item) => sum + item.text.length) >
        5000) {
      throw const PlannerExplanationContractException(
        'clauses_too_large',
        'The visible explanation packet exceeds its data-minimization limit.',
      );
    }
  }

  factory PlannerExplanationPacket.fromPlannerResponse(
    PlannerV2Response response,
  ) {
    if (response.isClarification) {
      throw const PlannerExplanationContractException(
        'plan_not_ready',
        'External explanation is available only after a deterministic plan exists.',
      );
    }
    final PlannerOption recommended = response.recommendedOption;
    return PlannerExplanationPacket(
      clauses: <PlannerExplanationClause>[
        PlannerExplanationClause(
          id: 'plan_focus',
          text: _bounded(response.mattersMost),
        ),
        PlannerExplanationClause(
          id: 'recommended_title',
          text: _bounded(recommended.title),
        ),
        PlannerExplanationClause(
          id: 'recommended_description',
          text: _bounded(recommended.description),
        ),
        PlannerExplanationClause(
          id: 'recommended_tradeoff',
          text: _bounded(recommended.tradeoff),
        ),
        PlannerExplanationClause(
          id: 'recommendation_reason',
          text: _bounded(response.recommendationReason),
        ),
        PlannerExplanationClause(
          id: 'next_step',
          text: _bounded(response.nextStep),
        ),
        ...response.verifiedEvidence
            .take(6)
            .indexed
            .map(
              ((int, String) entry) => PlannerExplanationClause(
                id: 'evidence_${entry.$1 + 1}',
                text: _bounded(entry.$2),
              ),
            ),
      ],
    );
  }

  final List<PlannerExplanationClause> clauses;

  String get responseDigest => sha256
      .convert(
        utf8.encode(
          jsonEncode(
            clauses
                .map((PlannerExplanationClause item) => item.toJson())
                .toList(growable: false),
          ),
        ),
      )
      .toString();

  Set<String> get clauseIds =>
      clauses.map((PlannerExplanationClause item) => item.id).toSet();

  Map<String, Object?> toRequestJson() => <String, Object?>{
    'responseDigest': responseDigest,
    'clauses': clauses
        .map((PlannerExplanationClause item) => item.toJson())
        .toList(growable: false),
  };

  void validateForExternalProcessing() {
    final String joined = clauses
        .map((PlannerExplanationClause item) => item.text)
        .join('\n');
    if (EmotionalSafetyPolicy.assess(joined).route !=
        EmotionalSafetyRoute.routine) {
      throw const PlannerExplanationContractException(
        'emotional_safety_route_required',
        'Sensitive content must stay on the deterministic safety route.',
      );
    }
    final String normalized = joined.toLowerCase();
    const List<String> instructionMarkers = <String>[
      'ignore previous instructions',
      'ignore all instructions',
      'system prompt',
      'developer message',
      'reveal your instructions',
      'call a tool',
      'run this instruction',
      'act as the system',
    ];
    if (instructionMarkers.any(normalized.contains)) {
      throw const PlannerExplanationContractException(
        'untrusted_instruction_detected',
        'Stored instruction-like text cannot be sent to the explanation service.',
      );
    }
  }
}

final class PlannerExplanationQuote {
  PlannerExplanationQuote.fromJson(Map<String, Object?> json)
    : schemaVersion = _requiredInt(json, 'schemaVersion'),
      operation = _requiredString(json, 'operation'),
      surface = _requiredString(json, 'surface'),
      requestId = _requiredString(json, 'requestId'),
      quoteId = _requiredString(json, 'quoteId'),
      expectedCredits = _requiredInt(json, 'expectedCredits'),
      provider = _requiredString(json, 'provider'),
      modelLabel = _requiredString(json, 'modelLabel'),
      promptVersion = _requiredString(json, 'promptVersion'),
      responseSchemaVersion = _requiredInt(json, 'responseSchemaVersion'),
      disclosureVersion = _requiredInt(json, 'disclosureVersion'),
      transmittedDataCategories = _requiredStringList(
        json,
        'transmittedDataCategories',
      ),
      replayWindowSeconds = _requiredInt(json, 'replayWindowSeconds'),
      providerRetentionStatus = _requiredString(
        json,
        'providerRetentionStatus',
      ),
      expiresAt = _requiredDateTime(json, 'expiresAt') {
    _requireExactKeys(json, const <String>{
      'schemaVersion',
      'operation',
      'surface',
      'requestId',
      'quoteId',
      'expectedCredits',
      'provider',
      'modelLabel',
      'promptVersion',
      'responseSchemaVersion',
      'disclosureVersion',
      'transmittedDataCategories',
      'replayWindowSeconds',
      'providerRetentionStatus',
      'expiresAt',
    });
    if (schemaVersion != plannerExplanationSchemaVersion ||
        operation != 'quote' ||
        surface != plannerExplanationSurface ||
        expectedCredits < 1 ||
        expectedCredits > 10 ||
        provider != 'Anthropic' ||
        responseSchemaVersion != plannerExplanationSchemaVersion ||
        disclosureVersion != plannerExplanationDisclosureVersion ||
        transmittedDataCategories.isEmpty ||
        replayWindowSeconds < 1 ||
        replayWindowSeconds > 300 ||
        providerRetentionStatus != 'verified_external_gate') {
      throw const PlannerExplanationContractException(
        'invalid_quote',
        'The explanation quote did not match the approved Phase 7 contract.',
      );
    }
  }

  final int schemaVersion;
  final String operation;
  final String surface;
  final String requestId;
  final String quoteId;
  final int expectedCredits;
  final String provider;
  final String modelLabel;
  final String promptVersion;
  final int responseSchemaVersion;
  final int disclosureVersion;
  final List<String> transmittedDataCategories;
  final int replayWindowSeconds;
  final String providerRetentionStatus;
  final DateTime expiresAt;
}

enum PlannerExplanationStatus { completed, replayExpired }

final class PlannerExplanationResult {
  PlannerExplanationResult.fromJson(Map<String, Object?> json)
    : schemaVersion = _requiredInt(json, 'schemaVersion'),
      operation = _requiredString(json, 'operation'),
      surface = _requiredString(json, 'surface'),
      requestId = _requiredString(json, 'requestId'),
      status = switch (_requiredString(json, 'status')) {
        'completed' => PlannerExplanationStatus.completed,
        'replay_expired' => PlannerExplanationStatus.replayExpired,
        _ => throw const PlannerExplanationContractException(
          'invalid_result_status',
          'The explanation service returned an unsupported status.',
        ),
      },
      responseDigest = _requiredString(json, 'responseDigest'),
      explanation = _optionalString(json, 'explanation'),
      sourceClauseIds = _optionalStringList(json, 'sourceClauseIds'),
      provider = _requiredString(json, 'provider'),
      modelLabel = _requiredString(json, 'modelLabel'),
      promptVersion = _requiredString(json, 'promptVersion'),
      responseSchemaVersion = _requiredInt(json, 'responseSchemaVersion'),
      expectedCredits = _requiredInt(json, 'expectedCredits'),
      creditsCharged = _requiredInt(json, 'creditsCharged'),
      remainingCredits = _requiredInt(json, 'remainingCredits'),
      contentExpiresAt = _optionalDateTime(json, 'contentExpiresAt'),
      replayState = _requiredString(json, 'replayState') {
    final Set<String> required = <String>{
      'schemaVersion',
      'operation',
      'surface',
      'requestId',
      'status',
      'responseDigest',
      'provider',
      'modelLabel',
      'promptVersion',
      'responseSchemaVersion',
      'expectedCredits',
      'creditsCharged',
      'remainingCredits',
      'replayState',
      if (status == PlannerExplanationStatus.completed) ...<String>{
        'explanation',
        'sourceClauseIds',
        'contentExpiresAt',
      },
    };
    _requireExactKeys(json, required);
    if (schemaVersion != plannerExplanationSchemaVersion ||
        operation != 'execute' ||
        surface != plannerExplanationSurface ||
        provider != 'Anthropic' ||
        responseSchemaVersion != plannerExplanationSchemaVersion ||
        expectedCredits < 1 ||
        creditsCharged < 0 ||
        creditsCharged > expectedCredits ||
        remainingCredits < 0 ||
        !const <String>{
          'fresh',
          'replayed',
          'content_scrubbed',
        }.contains(replayState)) {
      throw const PlannerExplanationContractException(
        'invalid_result',
        'The explanation result did not match the approved Phase 7 contract.',
      );
    }
    if (status == PlannerExplanationStatus.completed &&
        ((explanation?.trim().isEmpty ?? true) ||
            explanation!.length > 1200 ||
            sourceClauseIds.isEmpty ||
            contentExpiresAt == null)) {
      throw const PlannerExplanationContractException(
        'invalid_completed_result',
        'A completed explanation requires bounded content and provenance.',
      );
    }
    if (status == PlannerExplanationStatus.replayExpired &&
        (explanation != null ||
            sourceClauseIds.isNotEmpty ||
            contentExpiresAt != null ||
            creditsCharged != 0 ||
            replayState != 'content_scrubbed')) {
      throw const PlannerExplanationContractException(
        'invalid_scrubbed_replay',
        'Expired replay results may expose billing metadata only.',
      );
    }
  }

  final int schemaVersion;
  final String operation;
  final String surface;
  final String requestId;
  final PlannerExplanationStatus status;
  final String responseDigest;
  final String? explanation;
  final List<String> sourceClauseIds;
  final String provider;
  final String modelLabel;
  final String promptVersion;
  final int responseSchemaVersion;
  final int expectedCredits;
  final int creditsCharged;
  final int remainingCredits;
  final DateTime? contentExpiresAt;
  final String replayState;

  void validateAgainst(PlannerExplanationPacket packet) {
    if (responseDigest != packet.responseDigest) {
      throw const PlannerExplanationContractException(
        'response_digest_mismatch',
        'The explanation does not belong to the visible deterministic plan.',
      );
    }
    if (status == PlannerExplanationStatus.replayExpired) return;
    if (!packet.clauseIds.containsAll(sourceClauseIds)) {
      throw const PlannerExplanationContractException(
        'unknown_source_clause',
        'The explanation cited content outside the visible plan.',
      );
    }
    _validateExplanationSafety(explanation!, packet);
  }
}

void _validateExplanationSafety(
  String explanation,
  PlannerExplanationPacket packet,
) {
  final String normalized = explanation.toLowerCase();
  const List<String> prohibited = <String>[
    'i diagnosed',
    'you are diagnosed',
    'you have depression',
    'you have anxiety',
    'as your therapist',
    'i am your therapist',
    'i know exactly how you feel',
    'you are lazy',
    'you are anxious',
    'you are depressed',
    'i saved',
    'i moved',
    'i changed',
    'i created',
    'i deleted',
    'i completed',
    'creator confirmation is unnecessary',
    'override the deterministic',
    'ignore the deterministic',
    'you must do this',
  ];
  if (prohibited.any(normalized.contains)) {
    throw const PlannerExplanationContractException(
      'unsafe_explanation',
      'The external explanation crossed its read-only language boundary.',
    );
  }
  final Set<String> sourceNumbers = RegExp(r'\b\d+(?:\.\d+)?%?\b')
      .allMatches(packet.clauses.map((item) => item.text).join(' '))
      .map((RegExpMatch match) => match.group(0)!)
      .toSet();
  final Set<String> outputNumbers = RegExp(
    r'\b\d+(?:\.\d+)?%?\b',
  ).allMatches(explanation).map((RegExpMatch match) => match.group(0)!).toSet();
  if (!sourceNumbers.containsAll(outputNumbers)) {
    throw const PlannerExplanationContractException(
      'invented_precision',
      'The external explanation introduced unsupported numeric precision.',
    );
  }
}

String _bounded(String value) {
  final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= 500) return normalized;
  return normalized.substring(0, 500).trimRight();
}

void _requireExactKeys(Map<String, Object?> json, Set<String> expected) {
  if (json.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(json.keys.toSet()).isNotEmpty) {
    throw const PlannerExplanationContractException(
      'unexpected_response_fields',
      'The explanation response contained missing or unknown fields.',
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw PlannerExplanationContractException(
      'invalid_$key',
      'The explanation response field $key is invalid.',
    );
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw PlannerExplanationContractException(
      'invalid_$key',
      'The optional explanation response field $key is invalid.',
    );
  }
  return value.trim();
}

int _requiredInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! num || value.toInt() != value) {
    throw PlannerExplanationContractException(
      'invalid_$key',
      'The explanation response field $key must be an integer.',
    );
  }
  return value.toInt();
}

List<String> _requiredStringList(Map<String, Object?> json, String key) {
  final List<String> values = _optionalStringList(json, key);
  if (values.isEmpty) {
    throw PlannerExplanationContractException(
      'invalid_$key',
      'The explanation response field $key cannot be empty.',
    );
  }
  return values;
}

List<String> _optionalStringList(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) return const <String>[];
  if (value is! List ||
      value.any((Object? item) => item is! String || item.trim().isEmpty)) {
    throw PlannerExplanationContractException(
      'invalid_$key',
      'The explanation response field $key must contain strings.',
    );
  }
  return List<String>.unmodifiable(
    value.cast<String>().map((String item) => item.trim()),
  );
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final DateTime? value = _optionalDateTime(json, key);
  if (value == null) {
    throw PlannerExplanationContractException(
      'invalid_$key',
      'The explanation response field $key must be a UTC timestamp.',
    );
  }
  return value;
}

DateTime? _optionalDateTime(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw == null) return null;
  if (raw is! String) return null;
  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null || !parsed.isUtc) return null;
  return parsed;
}
