import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Planner and SI V2 production exits require the Phase 9 safety gate',
    () {
      final String planner = File(
        'lib/state/controllers/smart_planner_query_controller.dart',
      ).readAsStringSync();
      final String si = File(
        'lib/state/providers/si_v2_provider.dart',
      ).readAsStringSync();

      expect(planner, contains('AssistantSafetyPipeline'));
      expect(planner, contains('_requirePublishableSafety'));
      expect(planner, contains('AssistantSafetyRouteException'));
      expect(si, contains('AssistantSafetyPipeline'));
      expect(si, contains('response.withSafetyReceipt'));
      expect(si, contains('AssistantActionAuthority.readOnly'));
    },
  );

  test('bounded critic source has no tools, repositories, or raw history', () {
    final String safety = File(
      'lib/domain/policies/assistant_safety_policy.dart',
    ).readAsStringSync();

    expect(safety, contains('BoundedAssistantEvidenceCritic'));
    expect(safety, contains('draftDigest'));
    expect(safety, contains('repairAttempts <= 1'));
    expect(safety, isNot(contains('AssistantHistoryTurn')));
    expect(safety, isNot(contains('Repository')));
    expect(safety, isNot(contains('ToolCall')));
    expect(safety, isNot(contains('chainOfThought')));
  });

  test('safety receipts keep replay metadata privacy-safe', () {
    final String safety = File(
      'lib/domain/policies/assistant_safety_policy.dart',
    ).readAsStringSync();
    final int replayStart = safety.indexOf('Map<String, Object?> toReplayJson');
    final int replayEnd = safety.indexOf('\n  };', replayStart);
    final String replay = safety.substring(replayStart, replayEnd);

    expect(replay, contains("'responseDigest'"));
    expect(replay, contains("'evidenceIds'"));
    expect(replay, contains("'validatorIds'"));
    expect(replay, isNot(contains("'accountScopeId'")));
    expect(replay, isNot(contains("'responseText'")));
    expect(replay, isNot(contains("'history'")));
  });
}
