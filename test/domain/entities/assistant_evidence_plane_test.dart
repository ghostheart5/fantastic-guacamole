import 'dart:convert';

import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime observedAt = DateTime.utc(2026, 8, 20, 18);

  AssistantRequestEnvelope request({
    String accountScopeId = 'v2.user-test',
    AssistantConversationScope conversation =
        AssistantConversationScope.primarySmartPlanner,
    AssistantRequestKind kind = AssistantRequestKind.planningGuidance,
  }) => createAssistantRequestEnvelope(
    accountScopeId: accountScopeId,
    conversation: conversation,
    kind: kind,
    input: 'What should I do next?',
    now: observedAt,
    requestId: 'request-evidence-plane',
  );

  AssistantEvidenceBundle evidence(
    AssistantRequestEnvelope owner, {
    bool includeCalculation = false,
  }) => AssistantEvidenceBundle(
    requestId: owner.requestId,
    conversation: owner.conversation,
    collectedAt: observedAt,
    items: <AssistantEvidenceItem>[
      AssistantEvidenceItem(
        evidenceId: 'fact-energy',
        kind: AssistantEvidenceKind.userInput,
        sourceId: 'planner_check_in',
        entityId: 'energy',
        summary: 'The user reported 70 percent energy.',
        observedAt: observedAt,
        freshness: AssistantEvidenceFreshness.current,
      ),
      if (includeCalculation)
        AssistantEvidenceItem(
          evidenceId: 'calculation-capacity',
          kind: AssistantEvidenceKind.calculation,
          sourceId: 'capacity_model',
          summary: 'Available capacity is moderate.',
          observedAt: observedAt,
          freshness: AssistantEvidenceFreshness.current,
        ),
    ],
  );

  AssistantResponseEnvelope response(
    AssistantRequestEnvelope owner,
    AssistantEvidenceBundle bundle, {
    String message = 'Choose one moderate task.',
  }) => AssistantResponseEnvelope(
    responseId: 'response-evidence-plane',
    requestId: owner.requestId,
    accountScopeId: owner.accountScopeId,
    conversation: owner.conversation,
    status: AssistantResponseStatus.completed,
    message: message,
    processingMode: AssistantContractProcessingMode.onDevice,
    generatedAt: observedAt,
    evidence: bundle,
  );

  AssistantEvidenceManifest manifestFor({
    bool includeCalculation = false,
    String message = 'Choose one moderate task.',
  }) {
    final AssistantRequestEnvelope owner = request();
    return createAssistantEvidenceManifest(
      request: owner,
      evidence: evidence(owner, includeCalculation: includeCalculation),
      responseMessage: message,
      createdAt: observedAt,
    );
  }

  test(
    'strictly round-trips immutable facts with provenance and freshness',
    () {
      final AssistantRequestEnvelope owner = request();
      final AssistantEvidenceBundle bundle = evidence(owner);
      final AssistantResponseEnvelope typedResponse = response(owner, bundle);
      final AssistantEvidenceManifest original =
          createAssistantEvidenceManifest(
            request: owner,
            evidence: bundle,
            responseMessage: typedResponse.message,
            createdAt: observedAt,
          );

      final AssistantEvidenceManifest decoded =
          AssistantEvidenceManifest.fromJson(original.toJson());
      decoded.validateAgainstRequest(owner);
      decoded.validateAgainstResponse(typedResponse);

      expect(decoded.snapshotVersion, original.snapshotVersion);
      expect(decoded.facts.single.provenance.sourceId, 'planner_check_in');
      expect(
        decoded.overallFreshnessAt(observedAt.add(const Duration(minutes: 14))),
        EvidenceFreshness.current,
      );
      expect(
        decoded.overallFreshnessAt(observedAt.add(const Duration(minutes: 15))),
        EvidenceFreshness.stale,
      );
      expect(
        () =>
            (decoded.facts.single.value! as Map<String, Object?>)['new'] = true,
        throwsUnsupportedError,
      );
    },
  );

  test('freshness aggregation preserves stale and unknown states', () {
    final AssistantRequestEnvelope owner = request();
    AssistantEvidenceManifest withFreshness(
      List<AssistantEvidenceFreshness> values,
    ) {
      final AssistantEvidenceBundle bundle = AssistantEvidenceBundle(
        requestId: owner.requestId,
        conversation: owner.conversation,
        collectedAt: observedAt,
        items: <AssistantEvidenceItem>[
          for (int index = 0; index < values.length; index += 1)
            AssistantEvidenceItem(
              evidenceId: 'freshness-$index',
              kind: AssistantEvidenceKind.domainFact,
              sourceId: 'tasks',
              summary: 'Freshness fact $index.',
              observedAt: observedAt,
              freshness: values[index],
            ),
        ],
      );
      return createAssistantEvidenceManifest(
        request: owner,
        evidence: bundle,
        responseMessage: 'Freshness-aware response.',
        createdAt: observedAt,
      );
    }

    expect(
      withFreshness(<AssistantEvidenceFreshness>[
        AssistantEvidenceFreshness.current,
        AssistantEvidenceFreshness.unknown,
      ]).overallFreshnessAt(observedAt),
      EvidenceFreshness.unknown,
    );
    expect(
      withFreshness(<AssistantEvidenceFreshness>[
        AssistantEvidenceFreshness.unknown,
        AssistantEvidenceFreshness.stale,
      ]).overallFreshnessAt(observedAt),
      EvidenceFreshness.stale,
    );
  });

  test('detects fact and snapshot tampering during strict decoding', () {
    final AssistantEvidenceManifest original = manifestFor();
    final Map<String, Object?> tamperedValue = _mutableJson(original.toJson());
    final List<Object?> facts = tamperedValue['facts']! as List<Object?>;
    final Map<String, Object?> fact = facts.single! as Map<String, Object?>;
    fact['value'] = <String, Object?>{'summary': 'Altered observation'};

    expect(
      () => AssistantEvidenceManifest.fromJson(tamperedValue),
      throwsA(isA<EvidencePlaneException>()),
    );

    final Map<String, Object?> tamperedSnapshot = _mutableJson(
      original.toJson(),
    )..['snapshotVersion'] = 'forged-version';
    expect(
      () => AssistantEvidenceManifest.fromJson(tamperedSnapshot),
      throwsA(isA<EvidencePlaneException>()),
    );

    final Map<String, Object?> tamperedClaim = _mutableJson(original.toJson());
    final List<Object?> claims = tamperedClaim['claims']! as List<Object?>;
    (claims.single! as Map<String, Object?>)['summary'] = 'Altered claim';
    expect(
      () => AssistantEvidenceManifest.fromJson(tamperedClaim),
      throwsA(isA<EvidencePlaneException>()),
    );
  });

  test('binds claims to the exact response content', () {
    final AssistantRequestEnvelope owner = request();
    final AssistantEvidenceBundle bundle = evidence(owner);
    final AssistantEvidenceManifest manifest = createAssistantEvidenceManifest(
      request: owner,
      evidence: bundle,
      responseMessage: 'Choose one moderate task.',
      createdAt: observedAt,
    );

    manifest.validateAgainstResponse(response(owner, bundle));
    expect(
      () => manifest.validateAgainstResponse(
        response(owner, bundle, message: 'Do every task immediately.'),
      ),
      throwsA(isA<EvidencePlaneException>()),
    );
  });

  test('resolves every response segment to immutable evidence records', () {
    const String message =
        'Energy is moderate. Choose one task.\nReview after 15 minutes.';
    final AssistantRequestEnvelope owner = request();
    final AssistantEvidenceBundle bundle = evidence(owner);
    final AssistantResponseEnvelope typedResponse = response(
      owner,
      bundle,
      message: message,
    );
    final AssistantEvidenceManifest complete = createAssistantEvidenceManifest(
      request: owner,
      evidence: bundle,
      responseMessage: message,
      createdAt: observedAt,
    );

    expect(complete.claims, hasLength(4));
    for (final EvidenceClaim claim in complete.claims) {
      expect(claim.supportIds, <String>['fact-energy']);
    }
    complete.validateAgainstResponse(typedResponse);

    final List<EvidenceClaim> incompleteClaims = complete.claims
        .take(2)
        .toList();
    final String incompleteSnapshot = computeEvidenceSnapshotVersion(
      facts: complete.facts,
      calculations: complete.calculations,
      claims: incompleteClaims,
    );
    final AssistantEvidenceManifest missingSegment = AssistantEvidenceManifest(
      manifestId:
          '${complete.requestId}.manifest.${incompleteSnapshot.substring(0, 16)}',
      requestId: complete.requestId,
      accountScopeId: complete.accountScopeId,
      conversation: complete.conversation,
      createdAt: complete.createdAt,
      snapshotVersion: incompleteSnapshot,
      facts: complete.facts,
      calculations: complete.calculations,
      claims: incompleteClaims,
    );
    expect(
      () => missingSegment.validateAgainstResponse(typedResponse),
      throwsA(isA<EvidencePlaneException>()),
    );
  });

  test('rejects cross-account and cross-surface manifest reuse', () {
    final AssistantEvidenceManifest manifest = manifestFor();
    final AssistantRequestEnvelope otherAccount = request(
      accountScopeId: 'v2.other-user',
    );
    final AssistantRequestEnvelope otherSurface = request(
      conversation: AssistantConversationScope.primarySiConsole,
      kind: AssistantRequestKind.consoleQuery,
    );

    expect(
      () => manifest.validateAgainstRequest(otherAccount),
      throwsA(isA<EvidencePlaneException>()),
    );
    expect(
      () => manifest.validateAgainstRequest(otherSurface),
      throwsA(isA<EvidencePlaneException>()),
    );
  });

  test('calculations require facts and inherit their freshness', () {
    final AssistantRequestEnvelope owner = request();
    final AssistantEvidenceBundle bundle = evidence(
      owner,
      includeCalculation: true,
    );
    final AssistantEvidenceManifest manifest = createAssistantEvidenceManifest(
      request: owner,
      evidence: bundle,
      responseMessage: 'Choose one moderate task.',
      createdAt: observedAt,
    );

    expect(manifest.facts, hasLength(1));
    expect(manifest.calculations, hasLength(1));
    expect(manifest.calculations.single.inputIds, <String>['fact-energy']);
    expect(
      manifest.freshnessForRecord(
        'calculation-capacity',
        observedAt.add(const Duration(minutes: 16)),
      ),
      EvidenceFreshness.stale,
    );

    final AssistantEvidenceBundle unsupported = AssistantEvidenceBundle(
      requestId: owner.requestId,
      conversation: owner.conversation,
      collectedAt: observedAt,
      items: <AssistantEvidenceItem>[
        AssistantEvidenceItem(
          evidenceId: 'calculation-only',
          kind: AssistantEvidenceKind.calculation,
          sourceId: 'capacity_model',
          summary: 'Calculated without facts.',
          observedAt: observedAt,
        ),
      ],
    );
    expect(
      () => createAssistantEvidenceManifest(
        request: owner,
        evidence: unsupported,
        responseMessage: 'Unsupported.',
        createdAt: observedAt,
      ),
      throwsA(isA<EvidencePlaneException>()),
    );
  });

  test('rejects evidence observed or collected after response generation', () {
    final AssistantRequestEnvelope owner = request();
    final AssistantEvidenceBundle futureObservation = AssistantEvidenceBundle(
      requestId: owner.requestId,
      conversation: owner.conversation,
      collectedAt: observedAt,
      items: <AssistantEvidenceItem>[
        AssistantEvidenceItem(
          evidenceId: 'future-fact',
          kind: AssistantEvidenceKind.domainFact,
          sourceId: 'tasks',
          summary: 'Future observation.',
          observedAt: observedAt.add(const Duration(minutes: 1)),
        ),
      ],
    );
    expect(
      () => createAssistantEvidenceManifest(
        request: owner,
        evidence: futureObservation,
        responseMessage: 'Future evidence is invalid.',
        createdAt: observedAt,
      ),
      throwsA(isA<EvidencePlaneException>()),
    );

    final AssistantEvidenceBundle futureCollection = AssistantEvidenceBundle(
      requestId: owner.requestId,
      conversation: owner.conversation,
      collectedAt: observedAt.add(const Duration(minutes: 1)),
      items: evidence(owner).items,
    );
    final AssistantEvidenceManifest manifest = createAssistantEvidenceManifest(
      request: owner,
      evidence: futureCollection,
      responseMessage: 'Choose one moderate task.',
      createdAt: observedAt,
    );
    expect(
      () => manifest.validateAgainstResponse(response(owner, futureCollection)),
      throwsA(isA<EvidencePlaneException>()),
    );
  });

  test('rejects unresolved claim support and unknown schema fields', () {
    final AssistantEvidenceManifest original = manifestFor();
    final Map<String, Object?> unresolved = _mutableJson(original.toJson());
    final List<Object?> claims = unresolved['claims']! as List<Object?>;
    final Map<String, Object?> claim = claims.single! as Map<String, Object?>;
    claim['supportIds'] = <Object?>['missing-record'];
    expect(
      () => AssistantEvidenceManifest.fromJson(unresolved),
      throwsA(isA<EvidencePlaneException>()),
    );

    final Map<String, Object?> unknown = _mutableJson(original.toJson())
      ..['unexpected'] = true;
    expect(
      () => AssistantEvidenceManifest.fromJson(unknown),
      throwsA(isA<EvidencePlaneException>()),
    );

    final Map<String, Object?> unsupported = _mutableJson(original.toJson())
      ..['schemaVersion'] = 999;
    expect(
      () => AssistantEvidenceManifest.fromJson(unsupported),
      throwsA(isA<EvidencePlaneException>()),
    );
  });
}

Map<String, Object?> _mutableJson(Map<String, Object?> value) =>
    (jsonDecode(jsonEncode(value))! as Map<Object?, Object?>).map(
      (Object? key, Object? value) =>
          MapEntry<String, Object?>(key! as String, value),
    );
