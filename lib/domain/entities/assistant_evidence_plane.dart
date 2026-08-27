import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';

const int assistantEvidencePlaneSchemaVersion = 1;

enum EvidenceFreshness { current, stale, unknown }

enum EvidenceFactKind { observed, userProvided, policy, runtime, fallback }

enum EvidenceClaimKind {
  fact,
  calculation,
  inference,
  recommendation,
  systemNotice,
}

final class EvidencePlaneException implements FormatException {
  const EvidencePlaneException(this.message, [this.source, this.offset]);

  @override
  final String message;

  @override
  final Object? source;

  @override
  final int? offset;

  @override
  String toString() => 'EvidencePlaneException: $message';
}

final class EvidenceProvenance {
  EvidenceProvenance({
    this.schemaVersion = assistantEvidencePlaneSchemaVersion,
    required String sourceId,
    required String sourceVersion,
    String? entityId,
    required String fieldPath,
    required DateTime observedAt,
    DateTime? validUntil,
    required this.declaredFreshness,
  }) : sourceId = sourceId.trim(),
       sourceVersion = sourceVersion.trim(),
       entityId = entityId?.trim(),
       fieldPath = fieldPath.trim(),
       observedAt = observedAt.toUtc(),
       validUntil = validUntil?.toUtc() {
    validate();
  }

  final int schemaVersion;
  final String sourceId;
  final String sourceVersion;
  final String? entityId;
  final String fieldPath;
  final DateTime observedAt;
  final DateTime? validUntil;
  final EvidenceFreshness declaredFreshness;

  EvidenceFreshness freshnessAt(DateTime asOf) {
    if (declaredFreshness != EvidenceFreshness.current) {
      return declaredFreshness;
    }
    final DateTime boundary = validUntil!;
    return asOf.toUtc().isBefore(boundary)
        ? EvidenceFreshness.current
        : EvidenceFreshness.stale;
  }

  void validate() {
    if (schemaVersion != assistantEvidencePlaneSchemaVersion) {
      throw const EvidencePlaneException(
        'Unsupported evidence provenance schema version.',
      );
    }
    if (_isUnnormalized(sourceId) ||
        _isUnnormalized(sourceVersion) ||
        _isUnnormalized(fieldPath) ||
        entityId != null && _isUnnormalized(entityId!)) {
      throw const EvidencePlaneException(
        'Evidence provenance identifiers must be non-empty and normalized.',
      );
    }
    if (observedAt.year < 2020) {
      throw const EvidencePlaneException(
        'Evidence provenance timestamp is outside the supported range.',
      );
    }
    if (validUntil != null && validUntil!.isBefore(observedAt)) {
      throw const EvidencePlaneException(
        'Evidence freshness cannot expire before observation.',
      );
    }
    if (declaredFreshness == EvidenceFreshness.current &&
        (validUntil == null || !validUntil!.isAfter(observedAt))) {
      throw const EvidencePlaneException(
        'Current evidence requires a bounded freshness window.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'sourceId': sourceId,
    'sourceVersion': sourceVersion,
    'entityId': entityId,
    'fieldPath': fieldPath,
    'observedAt': observedAt.toIso8601String(),
    'validUntil': validUntil?.toIso8601String(),
    'declaredFreshness': declaredFreshness.name,
  };

  factory EvidenceProvenance.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'schemaVersion',
      'sourceId',
      'sourceVersion',
      'entityId',
      'fieldPath',
      'observedAt',
      'validUntil',
      'declaredFreshness',
    });
    return EvidenceProvenance(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      sourceId: _requiredString(json, 'sourceId'),
      sourceVersion: _requiredString(json, 'sourceVersion'),
      entityId: _optionalString(json, 'entityId'),
      fieldPath: _requiredString(json, 'fieldPath'),
      observedAt: _requiredDateTime(json, 'observedAt'),
      validUntil: _optionalDateTime(json, 'validUntil'),
      declaredFreshness: _enumValue(
        EvidenceFreshness.values,
        _requiredString(json, 'declaredFreshness'),
        'evidence freshness',
      ),
    );
  }
}

final class EvidenceFact {
  EvidenceFact({
    this.schemaVersion = assistantEvidencePlaneSchemaVersion,
    required String factId,
    required String requestId,
    required this.kind,
    required String summary,
    required Object? value,
    required this.provenance,
    String? valueDigest,
  }) : factId = factId.trim(),
       requestId = requestId.trim(),
       summary = summary.trim(),
       value = _freezeJsonValue(value, path: 'fact.value'),
       valueDigest =
           valueDigest ?? evidenceContentDigest(_freezeJsonValue(value)) {
    validate();
  }

  final int schemaVersion;
  final String factId;
  final String requestId;
  final EvidenceFactKind kind;
  final String summary;
  final Object? value;
  final String valueDigest;
  final EvidenceProvenance provenance;

  EvidenceFreshness freshnessAt(DateTime asOf) => provenance.freshnessAt(asOf);

  void validate() {
    if (schemaVersion != assistantEvidencePlaneSchemaVersion) {
      throw const EvidencePlaneException(
        'Unsupported evidence fact schema version.',
      );
    }
    if (_isUnnormalized(factId) ||
        _isUnnormalized(requestId) ||
        _isUnnormalized(summary)) {
      throw const EvidencePlaneException(
        'Evidence facts require normalized identity and summary.',
      );
    }
    provenance.validate();
    if (valueDigest != evidenceContentDigest(value)) {
      throw const EvidencePlaneException(
        'Evidence fact content does not match its integrity digest.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'factId': factId,
    'requestId': requestId,
    'kind': kind.name,
    'summary': summary,
    'value': value,
    'valueDigest': valueDigest,
    'provenance': provenance.toJson(),
  };

  factory EvidenceFact.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'schemaVersion',
      'factId',
      'requestId',
      'kind',
      'summary',
      'value',
      'valueDigest',
      'provenance',
    });
    return EvidenceFact(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      factId: _requiredString(json, 'factId'),
      requestId: _requiredString(json, 'requestId'),
      kind: _enumValue(
        EvidenceFactKind.values,
        _requiredString(json, 'kind'),
        'evidence fact kind',
      ),
      summary: _requiredString(json, 'summary'),
      value: json['value'],
      valueDigest: _requiredString(json, 'valueDigest'),
      provenance: EvidenceProvenance.fromJson(
        _stringObjectMap(json['provenance'], 'fact.provenance'),
      ),
    );
  }
}

final class EvidenceCalculation {
  EvidenceCalculation({
    this.schemaVersion = assistantEvidencePlaneSchemaVersion,
    required String calculationId,
    required String requestId,
    required String calculatorId,
    required String calculatorVersion,
    required String expression,
    required List<String> inputIds,
    required Object? result,
    required String summary,
    required DateTime calculatedAt,
    String? resultDigest,
  }) : calculationId = calculationId.trim(),
       requestId = requestId.trim(),
       calculatorId = calculatorId.trim(),
       calculatorVersion = calculatorVersion.trim(),
       expression = expression.trim(),
       inputIds = List<String>.unmodifiable(
         inputIds.map((String value) => value.trim()),
       ),
       result = _freezeJsonValue(result, path: 'calculation.result'),
       resultDigest =
           resultDigest ?? evidenceContentDigest(_freezeJsonValue(result)),
       summary = summary.trim(),
       calculatedAt = calculatedAt.toUtc() {
    validate();
  }

  final int schemaVersion;
  final String calculationId;
  final String requestId;
  final String calculatorId;
  final String calculatorVersion;
  final String expression;
  final List<String> inputIds;
  final Object? result;
  final String resultDigest;
  final String summary;
  final DateTime calculatedAt;

  void validate() {
    if (schemaVersion != assistantEvidencePlaneSchemaVersion) {
      throw const EvidencePlaneException(
        'Unsupported evidence calculation schema version.',
      );
    }
    if (_isUnnormalized(calculationId) ||
        _isUnnormalized(requestId) ||
        _isUnnormalized(calculatorId) ||
        _isUnnormalized(calculatorVersion) ||
        _isUnnormalized(expression) ||
        _isUnnormalized(summary) ||
        calculatedAt.year < 2020) {
      throw const EvidencePlaneException(
        'Evidence calculations require normalized, versioned identity.',
      );
    }
    if (inputIds.isEmpty ||
        inputIds.any(_isUnnormalized) ||
        inputIds.toSet().length != inputIds.length ||
        inputIds.contains(calculationId)) {
      throw const EvidencePlaneException(
        'Evidence calculations require unique, non-circular inputs.',
      );
    }
    if (resultDigest != evidenceContentDigest(result)) {
      throw const EvidencePlaneException(
        'Evidence calculation result does not match its integrity digest.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'calculationId': calculationId,
    'requestId': requestId,
    'calculatorId': calculatorId,
    'calculatorVersion': calculatorVersion,
    'expression': expression,
    'inputIds': inputIds,
    'result': result,
    'resultDigest': resultDigest,
    'summary': summary,
    'calculatedAt': calculatedAt.toIso8601String(),
  };

  factory EvidenceCalculation.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'schemaVersion',
      'calculationId',
      'requestId',
      'calculatorId',
      'calculatorVersion',
      'expression',
      'inputIds',
      'result',
      'resultDigest',
      'summary',
      'calculatedAt',
    });
    return EvidenceCalculation(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      calculationId: _requiredString(json, 'calculationId'),
      requestId: _requiredString(json, 'requestId'),
      calculatorId: _requiredString(json, 'calculatorId'),
      calculatorVersion: _requiredString(json, 'calculatorVersion'),
      expression: _requiredString(json, 'expression'),
      inputIds: _requiredList(json, 'inputIds')
          .map((Object? value) {
            if (value is! String) {
              throw const EvidencePlaneException(
                'Calculation input ids must be strings.',
              );
            }
            return value;
          })
          .toList(growable: false),
      result: json['result'],
      resultDigest: _requiredString(json, 'resultDigest'),
      summary: _requiredString(json, 'summary'),
      calculatedAt: _requiredDateTime(json, 'calculatedAt'),
    );
  }
}

final class EvidenceClaim {
  EvidenceClaim({
    this.schemaVersion = assistantEvidencePlaneSchemaVersion,
    required String claimId,
    required String requestId,
    required this.kind,
    required String contentDigest,
    required String summary,
    required List<String> supportIds,
    required DateTime createdAt,
  }) : claimId = claimId.trim(),
       requestId = requestId.trim(),
       contentDigest = contentDigest.trim(),
       summary = summary.trim(),
       supportIds = List<String>.unmodifiable(
         supportIds.map((String value) => value.trim()),
       ),
       createdAt = createdAt.toUtc() {
    validate();
  }

  factory EvidenceClaim.forContent({
    required String claimId,
    required String requestId,
    required EvidenceClaimKind kind,
    required String content,
    required String summary,
    required List<String> supportIds,
    required DateTime createdAt,
  }) {
    if (content.trim().isEmpty) {
      throw const EvidencePlaneException(
        'Evidence claims cannot bind empty response content.',
      );
    }
    return EvidenceClaim(
      claimId: claimId,
      requestId: requestId,
      kind: kind,
      contentDigest: evidenceContentDigest(content.trim()),
      summary: summary,
      supportIds: supportIds,
      createdAt: createdAt,
    );
  }

  final int schemaVersion;
  final String claimId;
  final String requestId;
  final EvidenceClaimKind kind;
  final String contentDigest;
  final String summary;
  final List<String> supportIds;
  final DateTime createdAt;

  bool covers(String content) =>
      contentDigest == evidenceContentDigest(content.trim());

  void validate() {
    if (schemaVersion != assistantEvidencePlaneSchemaVersion) {
      throw const EvidencePlaneException(
        'Unsupported evidence claim schema version.',
      );
    }
    if (_isUnnormalized(claimId) ||
        _isUnnormalized(requestId) ||
        _isUnnormalized(contentDigest) ||
        _isUnnormalized(summary) ||
        createdAt.year < 2020) {
      throw const EvidencePlaneException(
        'Evidence claims require normalized identity and content binding.',
      );
    }
    if (supportIds.isEmpty ||
        supportIds.any(_isUnnormalized) ||
        supportIds.toSet().length != supportIds.length) {
      throw const EvidencePlaneException(
        'Every evidence claim requires unique supporting records.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'claimId': claimId,
    'requestId': requestId,
    'kind': kind.name,
    'contentDigest': contentDigest,
    'summary': summary,
    'supportIds': supportIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory EvidenceClaim.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'schemaVersion',
      'claimId',
      'requestId',
      'kind',
      'contentDigest',
      'summary',
      'supportIds',
      'createdAt',
    });
    return EvidenceClaim(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      claimId: _requiredString(json, 'claimId'),
      requestId: _requiredString(json, 'requestId'),
      kind: _enumValue(
        EvidenceClaimKind.values,
        _requiredString(json, 'kind'),
        'evidence claim kind',
      ),
      contentDigest: _requiredString(json, 'contentDigest'),
      summary: _requiredString(json, 'summary'),
      supportIds: _requiredList(json, 'supportIds')
          .map((Object? value) {
            if (value is! String) {
              throw const EvidencePlaneException(
                'Claim support ids must be strings.',
              );
            }
            return value;
          })
          .toList(growable: false),
      createdAt: _requiredDateTime(json, 'createdAt'),
    );
  }
}

final class AssistantEvidenceManifest {
  AssistantEvidenceManifest({
    this.schemaVersion = assistantEvidencePlaneSchemaVersion,
    required String manifestId,
    required String requestId,
    required String accountScopeId,
    required this.conversation,
    required DateTime createdAt,
    required String snapshotVersion,
    required List<EvidenceFact> facts,
    List<EvidenceCalculation> calculations = const <EvidenceCalculation>[],
    required List<EvidenceClaim> claims,
  }) : manifestId = manifestId.trim(),
       requestId = requestId.trim(),
       accountScopeId = accountScopeId.trim(),
       createdAt = createdAt.toUtc(),
       snapshotVersion = snapshotVersion.trim(),
       facts = List<EvidenceFact>.unmodifiable(facts),
       calculations = List<EvidenceCalculation>.unmodifiable(calculations),
       claims = List<EvidenceClaim>.unmodifiable(claims) {
    validate();
  }

  final int schemaVersion;
  final String manifestId;
  final String requestId;
  final String accountScopeId;
  final AssistantConversationScope conversation;
  final DateTime createdAt;
  final String snapshotVersion;
  final List<EvidenceFact> facts;
  final List<EvidenceCalculation> calculations;
  final List<EvidenceClaim> claims;

  Set<String> get recordIds => <String>{
    ...facts.map((EvidenceFact fact) => fact.factId),
    ...calculations.map(
      (EvidenceCalculation calculation) => calculation.calculationId,
    ),
  };

  EvidenceFreshness freshnessForRecord(String recordId, DateTime asOf) {
    for (final EvidenceFact fact in facts) {
      if (fact.factId == recordId) return fact.freshnessAt(asOf);
    }
    final Map<String, EvidenceCalculation> byId = <String, EvidenceCalculation>{
      for (final EvidenceCalculation calculation in calculations)
        calculation.calculationId: calculation,
    };
    EvidenceFreshness resolve(String id, Set<String> visiting) {
      for (final EvidenceFact fact in facts) {
        if (fact.factId == id) return fact.freshnessAt(asOf);
      }
      final EvidenceCalculation? calculation = byId[id];
      if (calculation == null || !visiting.add(id)) {
        throw const EvidencePlaneException(
          'Cannot resolve evidence freshness for an unknown or cyclic record.',
        );
      }
      final List<EvidenceFreshness> inputs = calculation.inputIds
          .map((String input) => resolve(input, visiting))
          .toList(growable: false);
      visiting.remove(id);
      if (inputs.contains(EvidenceFreshness.stale)) {
        return EvidenceFreshness.stale;
      }
      if (inputs.contains(EvidenceFreshness.unknown)) {
        return EvidenceFreshness.unknown;
      }
      return EvidenceFreshness.current;
    }

    return resolve(recordId, <String>{});
  }

  EvidenceFreshness overallFreshnessAt(DateTime asOf) {
    final Set<String> supports = claims
        .expand((EvidenceClaim claim) => claim.supportIds)
        .toSet();
    final List<EvidenceFreshness> values = supports
        .map((String id) => freshnessForRecord(id, asOf))
        .toList(growable: false);
    if (values.contains(EvidenceFreshness.stale)) {
      return EvidenceFreshness.stale;
    }
    if (values.contains(EvidenceFreshness.unknown)) {
      return EvidenceFreshness.unknown;
    }
    return EvidenceFreshness.current;
  }

  void validate() {
    if (schemaVersion != assistantEvidencePlaneSchemaVersion) {
      throw const EvidencePlaneException(
        'Unsupported assistant evidence manifest schema version.',
      );
    }
    conversation.validate();
    if (_isUnnormalized(manifestId) ||
        _isUnnormalized(requestId) ||
        _isUnnormalized(accountScopeId) ||
        _isUnnormalized(snapshotVersion) ||
        createdAt.year < 2020) {
      throw const EvidencePlaneException(
        'Evidence manifests require normalized, versioned identity.',
      );
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(snapshotVersion) ||
        manifestId !=
            '$requestId.manifest.${snapshotVersion.substring(0, 16)}') {
      throw const EvidencePlaneException(
        'Evidence manifest identity must bind its request and snapshot.',
      );
    }
    if (facts.isEmpty && calculations.isEmpty) {
      throw const EvidencePlaneException(
        'Evidence manifests require at least one fact or calculation.',
      );
    }
    if (claims.isEmpty) {
      throw const EvidencePlaneException(
        'Evidence manifests require at least one supported claim.',
      );
    }

    final Set<String> available = <String>{};
    for (final EvidenceFact fact in facts) {
      fact.validate();
      if (fact.requestId != requestId ||
          fact.provenance.observedAt.isAfter(createdAt) ||
          !available.add(fact.factId)) {
        throw const EvidencePlaneException(
          'Evidence facts must be request-bound, ordered, and uniquely identified.',
        );
      }
    }
    for (final EvidenceCalculation calculation in calculations) {
      calculation.validate();
      if (calculation.requestId != requestId ||
          calculation.calculatedAt.isAfter(createdAt) ||
          !calculation.inputIds.every(available.contains) ||
          !available.add(calculation.calculationId)) {
        throw const EvidencePlaneException(
          'Evidence calculations must be ordered and uniquely bound to earlier inputs.',
        );
      }
    }
    final Set<String> claimIds = <String>{};
    final Set<String> supportedRecords = <String>{};
    for (final EvidenceClaim claim in claims) {
      claim.validate();
      if (claim.requestId != requestId ||
          claim.createdAt.isAfter(createdAt) ||
          !claimIds.add(claim.claimId) ||
          !claim.supportIds.every(available.contains)) {
        throw const EvidencePlaneException(
          'Evidence claims must be ordered with unique ids and resolvable support.',
        );
      }
      supportedRecords.addAll(claim.supportIds);
    }
    if (!supportedRecords.containsAll(available)) {
      throw const EvidencePlaneException(
        'Every evidence record must support at least one claim.',
      );
    }
    final String expectedSnapshot = computeEvidenceSnapshotVersion(
      facts: facts,
      calculations: calculations,
      claims: claims,
    );
    if (snapshotVersion != expectedSnapshot) {
      throw const EvidencePlaneException(
        'Evidence manifest snapshot does not match its immutable records.',
      );
    }
  }

  void validateAgainstRequest(AssistantRequestEnvelope request) {
    validate();
    if (requestId != request.requestId ||
        accountScopeId != request.accountScopeId ||
        conversation != request.conversation ||
        createdAt.isBefore(request.createdAt)) {
      throw const EvidencePlaneException(
        'Evidence manifest does not belong to its assistant request.',
      );
    }
  }

  void validateAgainstResponse(AssistantResponseEnvelope response) {
    validate();
    if (requestId != response.requestId ||
        accountScopeId != response.accountScopeId ||
        conversation != response.conversation ||
        createdAt.isAfter(response.generatedAt) ||
        response.evidence.collectedAt.isAfter(response.generatedAt)) {
      throw const EvidencePlaneException(
        'Evidence manifest does not belong to its assistant response.',
      );
    }
    final Map<String, AssistantEvidenceItem> responseItems =
        <String, AssistantEvidenceItem>{
          for (final AssistantEvidenceItem item in response.evidence.items)
            item.evidenceId: item,
        };
    if (responseItems.keys.toSet().length != recordIds.length ||
        !responseItems.keys.toSet().containsAll(recordIds)) {
      throw const EvidencePlaneException(
        'Response evidence and manifest records must have exact parity.',
      );
    }
    for (final EvidenceFact fact in facts) {
      final AssistantEvidenceItem? item = responseItems[fact.factId];
      if (item == null ||
          item.kind == AssistantEvidenceKind.calculation ||
          _toFactKind(item.kind) != fact.kind ||
          item.sourceId != fact.provenance.sourceId ||
          item.entityId != fact.provenance.entityId ||
          item.summary != fact.summary ||
          item.observedAt != fact.provenance.observedAt ||
          _toEvidenceFreshness(item.freshness) !=
              fact.provenance.declaredFreshness) {
        throw const EvidencePlaneException(
          'Response evidence fact does not match its provenance record.',
        );
      }
    }
    for (final EvidenceCalculation calculation in calculations) {
      final AssistantEvidenceItem? item =
          responseItems[calculation.calculationId];
      if (item == null ||
          item.kind != AssistantEvidenceKind.calculation ||
          item.sourceId != calculation.calculatorId ||
          item.summary != calculation.summary ||
          item.observedAt != calculation.calculatedAt) {
        throw const EvidencePlaneException(
          'Response calculation does not match its deterministic record.',
        );
      }
    }
    if (!claims.any((EvidenceClaim claim) => claim.covers(response.message))) {
      throw const EvidencePlaneException(
        'Assistant response text has no evidence-backed claim binding.',
      );
    }
    final bool everySegmentSupported = _evidenceClaimSegments(response.message)
        .every(
          (String segment) =>
              claims.any((EvidenceClaim claim) => claim.covers(segment)),
        );
    if (!everySegmentSupported) {
      throw const EvidencePlaneException(
        'Every assistant response segment must resolve to evidence.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'manifestId': manifestId,
    'requestId': requestId,
    'accountScopeId': accountScopeId,
    'surfaceId': conversation.surface.storageId,
    'conversationId': conversation.conversationId,
    'createdAt': createdAt.toIso8601String(),
    'snapshotVersion': snapshotVersion,
    'facts': facts
        .map((EvidenceFact fact) => fact.toJson())
        .toList(growable: false),
    'calculations': calculations
        .map((EvidenceCalculation calculation) => calculation.toJson())
        .toList(growable: false),
    'claims': claims
        .map((EvidenceClaim claim) => claim.toJson())
        .toList(growable: false),
  };

  factory AssistantEvidenceManifest.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'schemaVersion',
      'manifestId',
      'requestId',
      'accountScopeId',
      'surfaceId',
      'conversationId',
      'createdAt',
      'snapshotVersion',
      'facts',
      'calculations',
      'claims',
    });
    return AssistantEvidenceManifest(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      manifestId: _requiredString(json, 'manifestId'),
      requestId: _requiredString(json, 'requestId'),
      accountScopeId: _requiredString(json, 'accountScopeId'),
      conversation: AssistantConversationScope(
        surface: AssistantSurface.fromStorageId(
          _requiredString(json, 'surfaceId'),
        ),
        conversationId: _requiredString(json, 'conversationId'),
      ),
      createdAt: _requiredDateTime(json, 'createdAt'),
      snapshotVersion: _requiredString(json, 'snapshotVersion'),
      facts: _requiredList(json, 'facts')
          .map(
            (Object? value) =>
                EvidenceFact.fromJson(_stringObjectMap(value, 'manifest fact')),
          )
          .toList(growable: false),
      calculations: _requiredList(json, 'calculations')
          .map(
            (Object? value) => EvidenceCalculation.fromJson(
              _stringObjectMap(value, 'manifest calculation'),
            ),
          )
          .toList(growable: false),
      claims: _requiredList(json, 'claims')
          .map(
            (Object? value) => EvidenceClaim.fromJson(
              _stringObjectMap(value, 'manifest claim'),
            ),
          )
          .toList(growable: false),
    );
  }
}

final class AssistantEvidenceExchange {
  AssistantEvidenceExchange({
    this.schemaVersion = assistantEvidencePlaneSchemaVersion,
    required this.request,
    required this.response,
    required this.manifest,
  }) {
    validate();
  }

  final int schemaVersion;
  final AssistantRequestEnvelope request;
  final AssistantResponseEnvelope response;
  final AssistantEvidenceManifest manifest;

  void validate() {
    if (schemaVersion != assistantEvidencePlaneSchemaVersion) {
      throw const EvidencePlaneException(
        'Unsupported assistant evidence exchange schema version.',
      );
    }
    request.validate();
    response.validateAgainst(request);
    manifest.validateAgainstRequest(request);
    manifest.validateAgainstResponse(response);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'request': request.toJson(),
    'response': response.toJson(),
    'manifest': manifest.toJson(),
  };

  factory AssistantEvidenceExchange.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'schemaVersion',
      'request',
      'response',
      'manifest',
    });
    return AssistantEvidenceExchange(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      request: AssistantRequestEnvelope.fromJson(
        _stringObjectMap(json['request'], 'exchange.request'),
      ),
      response: AssistantResponseEnvelope.fromJson(
        _stringObjectMap(json['response'], 'exchange.response'),
      ),
      manifest: AssistantEvidenceManifest.fromJson(
        _stringObjectMap(json['manifest'], 'exchange.manifest'),
      ),
    );
  }
}

AssistantEvidenceManifest createAssistantEvidenceManifest({
  required AssistantRequestEnvelope request,
  required AssistantEvidenceBundle evidence,
  required String responseMessage,
  required DateTime createdAt,
  EvidenceClaimKind claimKind = EvidenceClaimKind.inference,
  Duration currentFor = const Duration(minutes: 15),
}) {
  evidence.validateAgainst(request);
  final DateTime created = createdAt.toUtc();
  if (responseMessage.trim().isEmpty) {
    throw const EvidencePlaneException(
      'Evidence manifests cannot bind an empty assistant response.',
    );
  }
  if (currentFor <= Duration.zero) {
    throw const EvidencePlaneException(
      'Evidence freshness windows must be positive.',
    );
  }
  final List<EvidenceFact> facts = <EvidenceFact>[];
  final List<AssistantEvidenceItem> calculationItems =
      <AssistantEvidenceItem>[];
  for (final AssistantEvidenceItem item in evidence.items) {
    if (item.kind == AssistantEvidenceKind.calculation) {
      calculationItems.add(item);
      continue;
    }
    final EvidenceFreshness freshness = _toEvidenceFreshness(item.freshness);
    final DateTime? validUntil = switch (freshness) {
      EvidenceFreshness.current => item.observedAt.add(currentFor),
      EvidenceFreshness.stale => item.observedAt,
      EvidenceFreshness.unknown => null,
    };
    final String sourceVersion = evidenceContentDigest(<String, Object?>{
      'sourceId': item.sourceId,
      'entityId': item.entityId,
      'summary': item.summary,
      'observedAt': item.observedAt.toIso8601String(),
      'freshness': item.freshness.name,
    });
    facts.add(
      EvidenceFact(
        factId: item.evidenceId,
        requestId: request.requestId,
        kind: _toFactKind(item.kind),
        summary: item.summary,
        value: <String, Object?>{'summary': item.summary},
        provenance: EvidenceProvenance(
          sourceId: item.sourceId,
          sourceVersion: sourceVersion,
          entityId: item.entityId,
          fieldPath: 'assistantEvidence.summary',
          observedAt: item.observedAt,
          validUntil: validUntil,
          declaredFreshness: freshness,
        ),
      ),
    );
  }
  if (calculationItems.isNotEmpty && facts.isEmpty) {
    throw const EvidencePlaneException(
      'Deterministic calculations require at least one factual input.',
    );
  }
  final List<EvidenceCalculation> calculations = <EvidenceCalculation>[];
  for (final AssistantEvidenceItem item in calculationItems) {
    calculations.add(
      EvidenceCalculation(
        calculationId: item.evidenceId,
        requestId: request.requestId,
        calculatorId: item.sourceId,
        calculatorVersion: evidenceContentDigest(<String, Object?>{
          'sourceId': item.sourceId,
          'summary': item.summary,
          'observedAt': item.observedAt.toIso8601String(),
        }),
        expression: item.summary,
        inputIds: facts.map((EvidenceFact fact) => fact.factId).toList(),
        result: <String, Object?>{'summary': item.summary},
        summary: item.summary,
        calculatedAt: item.observedAt,
      ),
    );
  }
  final List<String> supportIds = evidence.items
      .map((AssistantEvidenceItem item) => item.evidenceId)
      .toList(growable: false);
  final List<String> responseSegments = _evidenceClaimSegments(responseMessage);
  final List<EvidenceClaim> claims = <EvidenceClaim>[
    EvidenceClaim.forContent(
      claimId: '${request.requestId}.claim.response',
      requestId: request.requestId,
      kind: claimKind,
      content: responseMessage,
      summary: 'Complete assistant response',
      supportIds: supportIds,
      createdAt: created,
    ),
    for (int index = 0; index < responseSegments.length; index += 1)
      if (responseSegments[index] != responseMessage.trim())
        EvidenceClaim.forContent(
          claimId: '${request.requestId}.claim.segment.$index',
          requestId: request.requestId,
          kind: claimKind,
          content: responseSegments[index],
          summary: 'Assistant response segment ${index + 1}',
          supportIds: supportIds,
          createdAt: created,
        ),
  ];
  final String snapshotVersion = computeEvidenceSnapshotVersion(
    facts: facts,
    calculations: calculations,
    claims: claims,
  );
  return AssistantEvidenceManifest(
    manifestId:
        '${request.requestId}.manifest.${snapshotVersion.substring(0, 16)}',
    requestId: request.requestId,
    accountScopeId: request.accountScopeId,
    conversation: request.conversation,
    createdAt: created,
    snapshotVersion: snapshotVersion,
    facts: facts,
    calculations: calculations,
    claims: claims,
  );
}

String computeEvidenceSnapshotVersion({
  required List<EvidenceFact> facts,
  required List<EvidenceCalculation> calculations,
  required List<EvidenceClaim> claims,
}) {
  final List<Map<String, Object?>> factJson =
      facts.map((EvidenceFact fact) => fact.toJson()).toList(growable: false)
        ..sort(
          (Map<String, Object?> a, Map<String, Object?> b) =>
              (a['factId']! as String).compareTo(b['factId']! as String),
        );
  final List<Map<String, Object?>> calculationJson =
      calculations
          .map((EvidenceCalculation calculation) => calculation.toJson())
          .toList(growable: false)
        ..sort(
          (Map<String, Object?> a, Map<String, Object?> b) =>
              (a['calculationId']! as String).compareTo(
                b['calculationId']! as String,
              ),
        );
  final List<Map<String, Object?>> claimJson =
      claims
          .map((EvidenceClaim claim) => claim.toJson())
          .toList(growable: false)
        ..sort(
          (Map<String, Object?> a, Map<String, Object?> b) =>
              (a['claimId']! as String).compareTo(b['claimId']! as String),
        );
  return evidenceContentDigest(<String, Object?>{
    'facts': factJson,
    'calculations': calculationJson,
    'claims': claimJson,
  });
}

String evidenceContentDigest(Object? value) {
  final Object? canonical = _canonicalJsonValue(
    _freezeJsonValue(value, path: 'digest.value'),
  );
  return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
}

List<String> _evidenceClaimSegments(String content) {
  final String normalized = content.trim();
  final List<String> segments = <String>[];
  final StringBuffer current = StringBuffer();
  for (int index = 0; index < normalized.length; index += 1) {
    final String character = normalized[index];
    current.write(character);
    final bool terminal =
        character == '.' || character == '?' || character == '!';
    final bool lineEnd = character == '\n';
    final bool followedBySpace =
        index + 1 >= normalized.length || normalized[index + 1].trim().isEmpty;
    if (lineEnd || terminal && followedBySpace) {
      final String segment = current.toString().trim();
      if (segment.isNotEmpty) segments.add(segment);
      current.clear();
    }
  }
  final String remainder = current.toString().trim();
  if (remainder.isNotEmpty) segments.add(remainder);
  return List<String>.unmodifiable(segments);
}

EvidenceFreshness _toEvidenceFreshness(AssistantEvidenceFreshness freshness) =>
    switch (freshness) {
      AssistantEvidenceFreshness.current => EvidenceFreshness.current,
      AssistantEvidenceFreshness.stale => EvidenceFreshness.stale,
      AssistantEvidenceFreshness.unknown => EvidenceFreshness.unknown,
    };

EvidenceFactKind _toFactKind(AssistantEvidenceKind kind) => switch (kind) {
  AssistantEvidenceKind.userInput => EvidenceFactKind.userProvided,
  AssistantEvidenceKind.domainFact => EvidenceFactKind.observed,
  AssistantEvidenceKind.policy => EvidenceFactKind.policy,
  AssistantEvidenceKind.fallback => EvidenceFactKind.fallback,
  AssistantEvidenceKind.calculation => throw const EvidencePlaneException(
    'Calculation evidence must use a deterministic calculation record.',
  ),
};

Object? _freezeJsonValue(Object? value, {String path = 'value'}) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw EvidencePlaneException('$path contains a non-finite number.');
    }
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(
      List<Object?>.generate(
        value.length,
        (int index) => _freezeJsonValue(value[index], path: '$path[$index]'),
        growable: false,
      ),
    );
  }
  if (value is Map<Object?, Object?> &&
      value.keys.every((Object? key) => key is String)) {
    final Map<String, Object?> frozen = <String, Object?>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final String key = entry.key! as String;
      if (_isUnnormalized(key)) {
        throw EvidencePlaneException('$path contains a blank key.');
      }
      frozen[key] = _freezeJsonValue(entry.value, path: '$path.$key');
    }
    return UnmodifiableMapView<String, Object?>(frozen);
  }
  throw EvidencePlaneException(
    '$path contains unsupported value type ${value.runtimeType}.',
  );
}

Object? _canonicalJsonValue(Object? value) {
  if (value is List<Object?>) {
    return value.map(_canonicalJsonValue).toList(growable: false);
  }
  if (value is Map<Object?, Object?>) {
    final List<String> keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final String key in keys) key: _canonicalJsonValue(value[key]),
    };
  }
  return value;
}

bool _isUnnormalized(String value) =>
    value.trim().isEmpty || value != value.trim();

void _requireExactKeys(Map<String, Object?> json, Set<String> expected) {
  final Set<String> keys = json.keys.toSet();
  if (keys.difference(expected).isNotEmpty ||
      expected.difference(keys).isNotEmpty) {
    throw const EvidencePlaneException(
      'Evidence schema keys do not match the expected shape.',
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw EvidencePlaneException('$key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw EvidencePlaneException('$key must be null or a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! int) {
    throw EvidencePlaneException('$key must be an integer.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String) {
    throw EvidencePlaneException('$key must be an ISO-8601 string.');
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw EvidencePlaneException('$key is not a valid ISO-8601 time.');
  }
  return parsed.toUtc();
}

DateTime? _optionalDateTime(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw EvidencePlaneException('$key must be null or an ISO-8601 string.');
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw EvidencePlaneException('$key is not a valid ISO-8601 time.');
  }
  return parsed.toUtc();
}

List<Object?> _requiredList(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw EvidencePlaneException('$key must be a list.');
  }
  return value;
}

Map<String, Object?> _stringObjectMap(Object? value, String label) {
  if (value is Map<Object?, Object?> &&
      value.keys.every((Object? key) => key is String)) {
    return Map<String, Object?>.from(value);
  }
  throw EvidencePlaneException('$label must be a string-keyed object.');
}

T _enumValue<T extends Enum>(List<T> values, String name, String label) {
  for (final T value in values) {
    if (value.name == name) return value;
  }
  throw EvidencePlaneException('Unknown $label: $name.');
}
