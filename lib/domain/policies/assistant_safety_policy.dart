// CHRONOSPARK-CLASS: SHIPPING | Feature: Assistant safety
import 'dart:convert';

import 'package:crypto/crypto.dart';

const int assistantSafetyContractVersion = 1;

enum AssistantSafetySurface { smartPlanner, siConsole }

enum AssistantActionAuthority { readOnly, proposalOnly, confirmedCreator }

enum AssistantSafetyRisk { routine, complex, contradictory, highImpact, crisis }

enum AssistantSafetyDisposition {
  approved,
  approvedAfterCritic,
  repaired,
  withheld,
  crisisRoute,
}

enum AssistantCriticVerdict { approve, requestRepair, reject }

final class AssistantSafetyRouteException implements Exception {
  const AssistantSafetyRouteException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AssistantSafetyRouteException($code): $message';
}

final class AssistantSafetyBudget {
  const AssistantSafetyBudget({
    this.retrievalRounds = 1,
    this.clarificationQuestions = 0,
    this.generationAttempts = 1,
    this.repairAttempts = 0,
  });

  final int retrievalRounds;
  final int clarificationQuestions;
  final int generationAttempts;
  final int repairAttempts;

  bool get isWithinBounds =>
      retrievalRounds >= 0 &&
      retrievalRounds <= 1 &&
      clarificationQuestions >= 0 &&
      clarificationQuestions <= 1 &&
      generationAttempts == 1 &&
      repairAttempts >= 0 &&
      repairAttempts <= 1;
}

final class AssistantSafetyReview {
  AssistantSafetyReview({
    required String requestId,
    required String accountScopeId,
    required this.surface,
    required String responseText,
    required Iterable<String> evidenceIds,
    Iterable<String> evidenceUris = const <String>[],
    Iterable<String> untrustedData = const <String>[],
    required this.authority,
    required this.risk,
    this.crisisDetected = false,
    this.contradictionCount = 0,
    this.budget = const AssistantSafetyBudget(),
  }) : requestId = requestId.trim(),
       accountScopeId = accountScopeId.trim(),
       responseText = responseText.trim(),
       evidenceIds = List<String>.unmodifiable(
         evidenceIds.map((String value) => value.trim()),
       ),
       evidenceUris = List<String>.unmodifiable(
         evidenceUris.map((String value) => value.trim()),
       ),
       untrustedData = List<String>.unmodifiable(untrustedData);

  final String requestId;
  final String accountScopeId;
  final AssistantSafetySurface surface;
  final String responseText;
  final List<String> evidenceIds;
  final List<String> evidenceUris;
  final List<String> untrustedData;
  final AssistantActionAuthority authority;
  final AssistantSafetyRisk risk;
  final bool crisisDetected;
  final int contradictionCount;
  final AssistantSafetyBudget budget;
}

final class AssistantCriticPacket {
  const AssistantCriticPacket({
    required this.requestId,
    required this.surface,
    required this.draftDigest,
    required this.evidenceIds,
    required this.validatorFindings,
    required this.risk,
    required this.repairAttempts,
  });

  final String requestId;
  final AssistantSafetySurface surface;
  final String draftDigest;
  final List<String> evidenceIds;
  final List<String> validatorFindings;
  final AssistantSafetyRisk risk;
  final int repairAttempts;

  bool get containsRawConversation =>
      draftDigest.contains(' ') ||
      evidenceIds.any((String value) => value.contains('\n'));
}

final class AssistantCriticDecision {
  const AssistantCriticDecision({required this.verdict, required this.code});

  final AssistantCriticVerdict verdict;
  final String code;
}

abstract interface class AssistantEvidenceCritic {
  AssistantCriticDecision review(AssistantCriticPacket packet);
}

/// A bounded independent critic. It receives only a content digest, permitted
/// evidence identifiers, validator finding codes, and fixed budget metadata.
/// It never receives chat history, raw evidence text, tools, or write authority.
final class BoundedAssistantEvidenceCritic implements AssistantEvidenceCritic {
  const BoundedAssistantEvidenceCritic();

  @override
  AssistantCriticDecision review(AssistantCriticPacket packet) {
    if (packet.containsRawConversation ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(packet.draftDigest)) {
      return const AssistantCriticDecision(
        verdict: AssistantCriticVerdict.reject,
        code: 'critic_packet_not_minimized',
      );
    }
    if (packet.validatorFindings.contains('injection_to_action') ||
        packet.validatorFindings.contains('write_authority_violation') ||
        packet.validatorFindings.contains('evidence_outside_app')) {
      return const AssistantCriticDecision(
        verdict: AssistantCriticVerdict.reject,
        code: 'critic_rejected_unsafe_draft',
      );
    }
    if (packet.validatorFindings.isNotEmpty && packet.repairAttempts == 0) {
      return const AssistantCriticDecision(
        verdict: AssistantCriticVerdict.requestRepair,
        code: 'critic_requested_single_repair',
      );
    }
    if (packet.validatorFindings.isNotEmpty) {
      return const AssistantCriticDecision(
        verdict: AssistantCriticVerdict.reject,
        code: 'critic_rejected_after_repair_budget',
      );
    }
    return const AssistantCriticDecision(
      verdict: AssistantCriticVerdict.approve,
      code: 'critic_approved_grounded_draft',
    );
  }
}

final class AssistantSafetyReceipt {
  AssistantSafetyReceipt({
    this.contractVersion = assistantSafetyContractVersion,
    required String receiptId,
    required String requestId,
    required String accountScopeId,
    required this.surface,
    required this.disposition,
    required String responseDigest,
    required Iterable<String> evidenceIds,
    required Iterable<String> validatorIds,
    required Iterable<String> findingCodes,
    required this.criticInvoked,
    required this.criticCode,
    required this.confirmationState,
    required DateTime evaluatedAt,
  }) : receiptId = receiptId.trim(),
       requestId = requestId.trim(),
       accountScopeId = accountScopeId.trim(),
       responseDigest = responseDigest.trim(),
       evidenceIds = List<String>.unmodifiable(evidenceIds),
       validatorIds = List<String>.unmodifiable(validatorIds),
       findingCodes = List<String>.unmodifiable(findingCodes),
       evaluatedAt = evaluatedAt.toUtc() {
    if (contractVersion != assistantSafetyContractVersion ||
        receiptId.isEmpty ||
        requestId.isEmpty ||
        accountScopeId.isEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(responseDigest) ||
        validatorIds.isEmpty ||
        evaluatedAt.year < 2020) {
      throw StateError('Assistant safety receipt is invalid.');
    }
  }

  final int contractVersion;
  final String receiptId;
  final String requestId;
  final String accountScopeId;
  final AssistantSafetySurface surface;
  final AssistantSafetyDisposition disposition;
  final String responseDigest;
  final List<String> evidenceIds;
  final List<String> validatorIds;
  final List<String> findingCodes;
  final bool criticInvoked;
  final String? criticCode;
  final String confirmationState;
  final DateTime evaluatedAt;

  /// Privacy-safe replay contains contract and verification metadata only.
  /// It intentionally excludes prompts, replies, emotional content, and hidden
  /// reasoning.
  Map<String, Object?> toReplayJson() => <String, Object?>{
    'contractVersion': contractVersion,
    'receiptId': receiptId,
    'requestId': requestId,
    'surface': surface.name,
    'disposition': disposition.name,
    'responseDigest': responseDigest,
    'evidenceIds': evidenceIds,
    'validatorIds': validatorIds,
    'findingCodes': findingCodes,
    'criticInvoked': criticInvoked,
    'criticCode': criticCode,
    'confirmationState': confirmationState,
    'evaluatedAt': evaluatedAt.toIso8601String(),
  };
}

final class AssistantSafetyOutcome {
  const AssistantSafetyOutcome({
    required this.publishableText,
    required this.receipt,
  });

  final String publishableText;
  final AssistantSafetyReceipt receipt;

  bool get mayPublish =>
      receipt.disposition != AssistantSafetyDisposition.withheld &&
      receipt.disposition != AssistantSafetyDisposition.crisisRoute;
}

final class AssistantSafetyPipeline {
  const AssistantSafetyPipeline({
    this.critic = const BoundedAssistantEvidenceCritic(),
    this.clock = _utcNow,
  });

  final AssistantEvidenceCritic critic;
  final DateTime Function() clock;

  static const List<String> validatorIds = <String>[
    'assistant_contract_validator_v1',
    'evidence_authority_validator_v1',
    'prompt_injection_action_validator_v1',
    'crisis_pressure_validator_v1',
    'bounded_execution_validator_v1',
  ];

  AssistantSafetyOutcome evaluate(AssistantSafetyReview review) {
    final List<String> findings = _findings(review);
    final String digest = _digest(review.responseText);
    final DateTime evaluatedAt = clock().toUtc();

    if (review.crisisDetected || review.risk == AssistantSafetyRisk.crisis) {
      return AssistantSafetyOutcome(
        publishableText: '',
        receipt: _receipt(
          review: review,
          digest: digest,
          evaluatedAt: evaluatedAt,
          disposition: AssistantSafetyDisposition.crisisRoute,
          findings: <String>{'crisis_route_required', ...findings}.toList(),
          criticInvoked: false,
          criticCode: null,
        ),
      );
    }

    final bool criticRequired =
        review.risk != AssistantSafetyRisk.routine ||
        review.contradictionCount > 0 ||
        review.untrustedData.any(_looksLikeInstructionInjection);
    if (!criticRequired && findings.isEmpty) {
      return AssistantSafetyOutcome(
        publishableText: review.responseText,
        receipt: _receipt(
          review: review,
          digest: digest,
          evaluatedAt: evaluatedAt,
          disposition: AssistantSafetyDisposition.approved,
          findings: findings,
          criticInvoked: false,
          criticCode: null,
        ),
      );
    }

    final AssistantCriticDecision decision = critic.review(
      AssistantCriticPacket(
        requestId: review.requestId,
        surface: review.surface,
        draftDigest: digest,
        evidenceIds: review.evidenceIds,
        validatorFindings: findings,
        risk: review.risk,
        repairAttempts: review.budget.repairAttempts,
      ),
    );
    if (decision.verdict == AssistantCriticVerdict.requestRepair &&
        review.budget.repairAttempts == 0) {
      const String repaired =
          'I could not validate the first draft. Review the current evidence '
          'links and ask for one narrower, read-only answer.';
      return AssistantSafetyOutcome(
        publishableText: repaired,
        receipt: _receipt(
          review: review,
          digest: _digest(repaired),
          evaluatedAt: evaluatedAt,
          disposition: AssistantSafetyDisposition.repaired,
          findings: findings,
          criticInvoked: true,
          criticCode: decision.code,
        ),
      );
    }
    final bool approve = decision.verdict == AssistantCriticVerdict.approve;
    return AssistantSafetyOutcome(
      publishableText: approve ? review.responseText : '',
      receipt: _receipt(
        review: review,
        digest: digest,
        evaluatedAt: evaluatedAt,
        disposition: approve
            ? AssistantSafetyDisposition.approvedAfterCritic
            : AssistantSafetyDisposition.withheld,
        findings: findings,
        criticInvoked: true,
        criticCode: decision.code,
      ),
    );
  }

  List<String> _findings(AssistantSafetyReview review) {
    final List<String> findings = <String>[];
    if (review.requestId.isEmpty || review.accountScopeId.isEmpty) {
      findings.add('invalid_scope');
    }
    if (review.responseText.isEmpty) findings.add('empty_response');
    if (review.evidenceIds.isEmpty ||
        review.evidenceIds.any((String value) => value.isEmpty) ||
        review.evidenceIds.toSet().length != review.evidenceIds.length) {
      findings.add('invalid_evidence_manifest');
    }
    if (review.evidenceUris.any(
      (String value) => !value.startsWith('chronospark://'),
    )) {
      findings.add('evidence_outside_app');
    }
    if (!review.budget.isWithinBounds) {
      findings.add('execution_budget_exceeded');
    }
    if (review.contradictionCount < 0) {
      findings.add('invalid_contradictions');
    }

    final bool injectionInData = review.untrustedData.any(
      _looksLikeInstructionInjection,
    );
    final bool actionClaim = _claimsCompletedMutation(review.responseText);
    if (review.authority != AssistantActionAuthority.confirmedCreator &&
        actionClaim) {
      findings.add('write_authority_violation');
    }
    if (injectionInData && actionClaim) findings.add('injection_to_action');
    if (_containsHiddenReasoning(review.responseText)) {
      findings.add('hidden_reasoning_exposed');
    }
    if (review.crisisDetected &&
        _containsProductivityPressure(review.responseText)) {
      findings.add('crisis_productivity_pressure');
    }
    return List<String>.unmodifiable(findings.toSet());
  }

  AssistantSafetyReceipt _receipt({
    required AssistantSafetyReview review,
    required String digest,
    required DateTime evaluatedAt,
    required AssistantSafetyDisposition disposition,
    required List<String> findings,
    required bool criticInvoked,
    required String? criticCode,
  }) {
    final String receiptDigest = _digest(
      '${review.requestId}|${review.surface.name}|$digest|'
      '${disposition.name}|${findings.join(',')}|${evaluatedAt.toIso8601String()}',
    );
    return AssistantSafetyReceipt(
      receiptId: 'safety-${receiptDigest.substring(0, 24)}',
      requestId: review.requestId,
      accountScopeId: review.accountScopeId,
      surface: review.surface,
      disposition: disposition,
      responseDigest: digest,
      evidenceIds: review.evidenceIds,
      validatorIds: validatorIds,
      findingCodes: findings,
      criticInvoked: criticInvoked,
      criticCode: criticCode,
      confirmationState: switch (review.authority) {
        AssistantActionAuthority.readOnly => 'not_applicable_read_only',
        AssistantActionAuthority.proposalOnly =>
          'creator_confirmation_required',
        AssistantActionAuthority.confirmedCreator => 'creator_confirmed',
      },
      evaluatedAt: evaluatedAt,
    );
  }
}

bool _looksLikeInstructionInjection(String value) {
  final String normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return <String>[
    'ignore previous',
    'ignore all instructions',
    'system prompt',
    'developer message',
    'reveal your prompt',
    'call the tool',
    'execute ',
    'delete all',
    'bypass safety',
    'jailbreak',
  ].any(normalized.contains);
}

bool _claimsCompletedMutation(String value) {
  final String normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return RegExp(
    r'\b(i|we|si|chronospark|the assistant)\s+((has|have)\s+)?'
    r'(saved|created|deleted|scheduled|completed|updated|sent|applied)\b',
  ).hasMatch(normalized);
}

bool _containsHiddenReasoning(String value) {
  final String normalized = value.toLowerCase();
  return normalized.contains('chain of thought') ||
      normalized.contains('hidden reasoning:') ||
      normalized.contains('internal scratchpad:');
}

bool _containsProductivityPressure(String value) {
  final String normalized = value.toLowerCase();
  return normalized.contains('xp') ||
      normalized.contains('streak') ||
      normalized.contains('momentum score') ||
      normalized.contains('do it now') ||
      normalized.contains('no excuses');
}

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();

DateTime _utcNow() => DateTime.now().toUtc();
