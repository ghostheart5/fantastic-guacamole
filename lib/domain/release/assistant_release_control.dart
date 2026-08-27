import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

const int assistantReleaseSchemaVersion = 1;

enum AssistantReleaseStage { off, internal, optedInBeta, canary, general }

enum AssistantReleaseCapability {
  smartPlannerV2,
  siConsoleV2,
  governedMemory,
  safetyCritic,
}

enum AssistantReleaseCohort { excluded, internal, optedInBeta, canary, general }

@immutable
final class AssistantReleaseConfig {
  AssistantReleaseConfig({
    required this.stage,
    required this.canaryBasisPoints,
    required this.shadowEvaluationEnabled,
    required Set<String> internalAccountDigests,
    required Set<AssistantReleaseCapability> rollbackCapabilities,
    this.schemaVersion = assistantReleaseSchemaVersion,
    this.configurationValid = true,
    this.configurationIssue,
  }) : internalAccountDigests = Set<String>.unmodifiable(
         internalAccountDigests,
       ),
       rollbackCapabilities = Set<AssistantReleaseCapability>.unmodifiable(
         rollbackCapabilities,
       ) {
    if (schemaVersion != assistantReleaseSchemaVersion) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (canaryBasisPoints < 0 || canaryBasisPoints > 10000) {
      throw ArgumentError.value(canaryBasisPoints, 'canaryBasisPoints');
    }
  }

  factory AssistantReleaseConfig.failClosed(String issue) {
    return AssistantReleaseConfig(
      stage: AssistantReleaseStage.off,
      canaryBasisPoints: 0,
      shadowEvaluationEnabled: false,
      internalAccountDigests: const <String>{},
      rollbackCapabilities: AssistantReleaseCapability.values.toSet(),
      configurationValid: false,
      configurationIssue: issue.trim().isEmpty
          ? 'invalid_release_configuration'
          : issue.trim(),
    );
  }

  static AssistantReleaseConfig fromRemote({
    required String stage,
    required int canaryBasisPoints,
    required bool shadowEvaluationEnabled,
    required Iterable<String> internalAccountDigests,
    required Iterable<AssistantReleaseCapability> rollbackCapabilities,
  }) {
    final AssistantReleaseStage? parsedStage = switch (stage.trim()) {
      'off' => AssistantReleaseStage.off,
      'internal' => AssistantReleaseStage.internal,
      'opted_in_beta' => AssistantReleaseStage.optedInBeta,
      'canary' => AssistantReleaseStage.canary,
      'general' => AssistantReleaseStage.general,
      _ => null,
    };
    if (parsedStage == null) {
      return AssistantReleaseConfig.failClosed('unknown_release_stage');
    }
    if (canaryBasisPoints < 0 || canaryBasisPoints > 10000) {
      return AssistantReleaseConfig.failClosed('invalid_canary_basis_points');
    }
    final Set<String> normalizedInternal = <String>{};
    for (final String digest in internalAccountDigests) {
      final String normalized = digest.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
        return AssistantReleaseConfig.failClosed(
          'invalid_internal_account_digest',
        );
      }
      normalizedInternal.add(normalized);
    }
    return AssistantReleaseConfig(
      stage: parsedStage,
      canaryBasisPoints: canaryBasisPoints,
      shadowEvaluationEnabled: shadowEvaluationEnabled,
      internalAccountDigests: normalizedInternal,
      rollbackCapabilities: rollbackCapabilities.toSet(),
    );
  }

  final int schemaVersion;
  final AssistantReleaseStage stage;
  final int canaryBasisPoints;
  final bool shadowEvaluationEnabled;
  final Set<String> internalAccountDigests;
  final Set<AssistantReleaseCapability> rollbackCapabilities;
  final bool configurationValid;
  final String? configurationIssue;

  bool isRolledBack(AssistantReleaseCapability capability) {
    return rollbackCapabilities.contains(capability);
  }

  String get digest => sha256
      .convert(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'schema': schemaVersion,
            'stage': stage.name,
            'canaryBasisPoints': canaryBasisPoints,
            'shadow': shadowEvaluationEnabled,
            'internal': internalAccountDigests.toList()..sort(),
            'rollbacks':
                rollbackCapabilities
                    .map((AssistantReleaseCapability item) => item.name)
                    .toList()
                  ..sort(),
            'valid': configurationValid,
            'issue': configurationIssue,
          }),
        ),
      )
      .toString();
}

@immutable
final class AssistantReleaseRequest {
  const AssistantReleaseRequest({
    required this.accountScopeId,
    required this.capability,
    required this.betaOptIn,
  });

  final String accountScopeId;
  final AssistantReleaseCapability capability;
  final bool betaOptIn;
}

@immutable
final class AssistantReleaseDecision {
  const AssistantReleaseDecision({
    required this.enabled,
    required this.shadowEvaluationEnabled,
    required this.cohort,
    required this.reasonCode,
    required this.accountDigest,
    required this.capability,
    required this.configDigest,
  });

  final bool enabled;
  final bool shadowEvaluationEnabled;
  final AssistantReleaseCohort cohort;
  final String reasonCode;
  final String accountDigest;
  final AssistantReleaseCapability capability;
  final String configDigest;

  Map<String, Object?> toPrivacySafeReceipt() => <String, Object?>{
    'schema': assistantReleaseSchemaVersion,
    'enabled': enabled,
    'shadow': shadowEvaluationEnabled,
    'cohort': cohort.name,
    'reason': reasonCode,
    'accountDigest': accountDigest,
    'capability': capability.name,
    'configDigest': configDigest,
  };
}

final class AssistantReleaseController {
  const AssistantReleaseController();

  AssistantReleaseDecision decide({
    required AssistantReleaseConfig config,
    required AssistantReleaseRequest request,
  }) {
    final String accountDigest = assistantReleaseAccountDigest(
      request.accountScopeId,
    );
    if (!config.configurationValid) {
      return _decision(
        enabled: false,
        shadow: false,
        cohort: AssistantReleaseCohort.excluded,
        reason: config.configurationIssue ?? 'invalid_release_configuration',
        accountDigest: accountDigest,
        request: request,
        config: config,
      );
    }
    if (config.isRolledBack(request.capability)) {
      return _decision(
        enabled: false,
        shadow: false,
        cohort: AssistantReleaseCohort.excluded,
        reason: 'capability_rollback_active',
        accountDigest: accountDigest,
        request: request,
        config: config,
      );
    }

    final bool isInternal = config.internalAccountDigests.contains(
      accountDigest,
    );
    final AssistantReleaseCohort cohort;
    final bool enabled;
    switch (config.stage) {
      case AssistantReleaseStage.off:
        cohort = AssistantReleaseCohort.excluded;
        enabled = false;
      case AssistantReleaseStage.internal:
        cohort = isInternal
            ? AssistantReleaseCohort.internal
            : AssistantReleaseCohort.excluded;
        enabled = isInternal;
      case AssistantReleaseStage.optedInBeta:
        cohort = isInternal
            ? AssistantReleaseCohort.internal
            : request.betaOptIn
            ? AssistantReleaseCohort.optedInBeta
            : AssistantReleaseCohort.excluded;
        enabled = isInternal || request.betaOptIn;
      case AssistantReleaseStage.canary:
        final bool isCanary =
            _canaryBucket(accountDigest) < config.canaryBasisPoints;
        cohort = isInternal
            ? AssistantReleaseCohort.internal
            : request.betaOptIn
            ? AssistantReleaseCohort.optedInBeta
            : isCanary
            ? AssistantReleaseCohort.canary
            : AssistantReleaseCohort.excluded;
        enabled = isInternal || request.betaOptIn || isCanary;
      case AssistantReleaseStage.general:
        cohort = isInternal
            ? AssistantReleaseCohort.internal
            : request.betaOptIn
            ? AssistantReleaseCohort.optedInBeta
            : AssistantReleaseCohort.general;
        enabled = true;
    }
    return _decision(
      enabled: enabled,
      shadow: config.shadowEvaluationEnabled,
      cohort: cohort,
      reason: enabled ? 'cohort_enabled' : 'cohort_not_enabled',
      accountDigest: accountDigest,
      request: request,
      config: config,
    );
  }

  AssistantReleaseDecision _decision({
    required bool enabled,
    required bool shadow,
    required AssistantReleaseCohort cohort,
    required String reason,
    required String accountDigest,
    required AssistantReleaseRequest request,
    required AssistantReleaseConfig config,
  }) {
    return AssistantReleaseDecision(
      enabled: enabled,
      shadowEvaluationEnabled: shadow,
      cohort: cohort,
      reasonCode: reason,
      accountDigest: accountDigest,
      capability: request.capability,
      configDigest: config.digest,
    );
  }
}

@immutable
final class AssistantShadowObservation {
  const AssistantShadowObservation({
    required this.requestDigest,
    required this.baselineResponseDigest,
    required this.candidateResponseDigest,
    required this.evidenceCount,
    required this.baselineFindingCodes,
    required this.candidateFindingCodes,
  });

  final String requestDigest;
  final String baselineResponseDigest;
  final String candidateResponseDigest;
  final int evidenceCount;
  final Set<String> baselineFindingCodes;
  final Set<String> candidateFindingCodes;

  void validate() {
    final RegExp digestPattern = RegExp(r'^[a-f0-9]{64}$');
    if (!digestPattern.hasMatch(requestDigest) ||
        !digestPattern.hasMatch(baselineResponseDigest) ||
        !digestPattern.hasMatch(candidateResponseDigest) ||
        evidenceCount < 0 ||
        evidenceCount > 1000) {
      throw ArgumentError('Invalid privacy-safe shadow observation.');
    }
  }
}

@immutable
final class AssistantShadowResult {
  const AssistantShadowResult({
    required this.responsesMatch,
    required this.addedFindingCodes,
    required this.removedFindingCodes,
  });

  final bool responsesMatch;
  final Set<String> addedFindingCodes;
  final Set<String> removedFindingCodes;

  bool get mayPublish => false;
  bool get mayWrite => false;
}

final class AssistantShadowEvaluator {
  const AssistantShadowEvaluator();

  AssistantShadowResult evaluate(AssistantShadowObservation observation) {
    observation.validate();
    return AssistantShadowResult(
      responsesMatch:
          observation.baselineResponseDigest ==
          observation.candidateResponseDigest,
      addedFindingCodes: Set<String>.unmodifiable(
        observation.candidateFindingCodes.difference(
          observation.baselineFindingCodes,
        ),
      ),
      removedFindingCodes: Set<String>.unmodifiable(
        observation.baselineFindingCodes.difference(
          observation.candidateFindingCodes,
        ),
      ),
    );
  }
}

final class AssistantReleaseBlockedException implements Exception {
  const AssistantReleaseBlockedException(this.decision);

  final AssistantReleaseDecision decision;

  @override
  String toString() =>
      'AssistantReleaseBlockedException(${decision.reasonCode}, '
      '${decision.capability.name})';
}

String assistantReleaseAccountDigest(String accountScopeId) {
  return sha256.convert(utf8.encode(accountScopeId.trim())).toString();
}

int _canaryBucket(String accountDigest) {
  return int.parse(accountDigest.substring(0, 8), radix: 16) % 10000;
}
