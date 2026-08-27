import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AssistantReleaseController controller = AssistantReleaseController();

  AssistantReleaseConfig config({
    AssistantReleaseStage stage = AssistantReleaseStage.general,
    int canaryBasisPoints = 0,
    bool shadow = false,
    Set<String> internal = const <String>{},
    Set<AssistantReleaseCapability> rollbacks =
        const <AssistantReleaseCapability>{},
  }) {
    return AssistantReleaseConfig(
      stage: stage,
      canaryBasisPoints: canaryBasisPoints,
      shadowEvaluationEnabled: shadow,
      internalAccountDigests: internal,
      rollbackCapabilities: rollbacks,
    );
  }

  AssistantReleaseDecision decide({
    required AssistantReleaseConfig config,
    String account = 'v2.account-a',
    AssistantReleaseCapability capability =
        AssistantReleaseCapability.smartPlannerV2,
    bool optIn = false,
  }) {
    return controller.decide(
      config: config,
      request: AssistantReleaseRequest(
        accountScopeId: account,
        capability: capability,
        betaOptIn: optIn,
      ),
    );
  }

  test(
    'malformed remote release configuration fails every capability closed',
    () {
      final AssistantReleaseConfig invalid = AssistantReleaseConfig.fromRemote(
        stage: 'surprise_launch',
        canaryBasisPoints: 500,
        shadowEvaluationEnabled: true,
        internalAccountDigests: const <String>[],
        rollbackCapabilities: const <AssistantReleaseCapability>[],
      );

      expect(invalid.configurationValid, isFalse);
      for (final AssistantReleaseCapability capability
          in AssistantReleaseCapability.values) {
        final AssistantReleaseDecision decision = decide(
          config: invalid,
          capability: capability,
        );
        expect(decision.enabled, isFalse);
        expect(decision.shadowEvaluationEnabled, isFalse);
        expect(decision.cohort, AssistantReleaseCohort.excluded);
      }
    },
  );

  test('internal and beta stages require their exact eligibility', () {
    final String internalDigest = assistantReleaseAccountDigest('v2.internal');
    final AssistantReleaseConfig internalConfig = config(
      stage: AssistantReleaseStage.internal,
      internal: <String>{internalDigest},
    );
    expect(
      decide(config: internalConfig, account: 'v2.internal').cohort,
      AssistantReleaseCohort.internal,
    );
    expect(decide(config: internalConfig).enabled, isFalse);

    final AssistantReleaseConfig betaConfig = config(
      stage: AssistantReleaseStage.optedInBeta,
    );
    expect(decide(config: betaConfig, optIn: false).enabled, isFalse);
    expect(
      decide(config: betaConfig, optIn: true).cohort,
      AssistantReleaseCohort.optedInBeta,
    );
  });

  test('canary assignment is stable and bounded across 10000 accounts', () {
    final AssistantReleaseConfig canaryConfig = config(
      stage: AssistantReleaseStage.canary,
      canaryBasisPoints: 1000,
    );
    int enabled = 0;
    for (int index = 0; index < 10000; index++) {
      final String account = 'v2.canary-$index';
      final AssistantReleaseDecision first = decide(
        config: canaryConfig,
        account: account,
      );
      final AssistantReleaseDecision second = decide(
        config: canaryConfig,
        account: account,
      );
      expect(second.enabled, first.enabled);
      expect(second.accountDigest, first.accountDigest);
      if (first.enabled) enabled++;
    }
    expect(enabled, inInclusiveRange(850, 1150));
  });

  test('each capability has an independent rollback switch', () {
    for (final AssistantReleaseCapability rolledBack
        in AssistantReleaseCapability.values) {
      final AssistantReleaseConfig release = config(
        rollbacks: <AssistantReleaseCapability>{rolledBack},
      );
      for (final AssistantReleaseCapability capability
          in AssistantReleaseCapability.values) {
        final AssistantReleaseDecision decision = decide(
          config: release,
          capability: capability,
        );
        expect(decision.enabled, capability != rolledBack);
      }
    }
  });

  test('privacy-safe receipt does not retain the account scope', () {
    const String account = 'v2.private-account-identity';
    final AssistantReleaseDecision decision = decide(
      config: config(shadow: true),
      account: account,
    );
    final String receipt = jsonEncode(decision.toPrivacySafeReceipt());

    expect(receipt, isNot(contains(account)));
    expect(decision.accountDigest, hasLength(64));
    expect(decision.shadowEvaluationEnabled, isTrue);
  });

  test('shadow evaluation is structurally unable to publish or write', () {
    String digest(String value) =>
        sha256.convert(utf8.encode(value)).toString();
    final AssistantShadowResult result = const AssistantShadowEvaluator()
        .evaluate(
          AssistantShadowObservation(
            requestDigest: digest('request'),
            baselineResponseDigest: digest('baseline'),
            candidateResponseDigest: digest('candidate'),
            evidenceCount: 3,
            baselineFindingCodes: const <String>{'grounded'},
            candidateFindingCodes: const <String>{
              'grounded',
              'better_provenance',
            },
          ),
        );

    expect(result.responsesMatch, isFalse);
    expect(result.addedFindingCodes, <String>{'better_provenance'});
    expect(result.mayPublish, isFalse);
    expect(result.mayWrite, isFalse);
  });
}
