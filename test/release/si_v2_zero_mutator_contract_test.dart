import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SI V2 analysis dependency graph exposes zero mutation authority', () {
    final String engine = File(
      'lib/engine/si/si_v2_engine.dart',
    ).readAsStringSync();
    final String contract = File(
      'lib/domain/entities/si_v2_contract.dart',
    ).readAsStringSync();
    final String gateway = File(
      'lib/state/services/si_v2_read_gateway.dart',
    ).readAsStringSync();
    final String composition = File(
      'lib/state/providers/si_v2_provider.dart',
    ).readAsStringSync();
    final String screen = File(
      'lib/features/si_console/ui/si_console_screen.dart',
    ).readAsStringSync();

    for (final String forbidden in <String>[
      'saveTask',
      'deleteTask',
      'saveGoal',
      'deleteGoal',
      'saveMilestones',
      'addEvent',
      'saveEvents',
      'removeEvent',
      'memoriesActionsProvider',
      'siStateProvider.notifier',
      'profileProvider.notifier',
    ]) {
      expect(engine, isNot(contains(forbidden)), reason: forbidden);
      expect(contract, isNot(contains(forbidden)), reason: forbidden);
      expect(gateway, isNot(contains(forbidden)), reason: forbidden);
      expect(composition, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(engine, isNot(contains('/state/providers/')));
    expect(engine, isNot(contains('/domain/interfaces/')));
    expect(gateway, contains('The only domain capability available to SI V2'));
    expect(gateway, contains('final SIV2TaskReader readTasks'));
    expect(composition, isNot(contains('/domain/interfaces/')));
    expect(composition, isNot(contains('RepositoryProvider')));
    expect(composition, contains('final GetTasks tasks'));
    expect(composition, contains('final GetGoals goals'));
    expect(composition, contains('final GetMilestones milestones'));
    expect(composition, contains('final GetTimelineEvents timeline'));
    expect(screen, isNot(contains('aiControllerProvider')));
    expect(screen, isNot(contains('adaptiveGuidanceProvider')));
    expect(screen, isNot(contains('siStateAggregationProvider')));
    expect(screen, isNot(contains('siConsoleThreadStoreProvider')));
    expect(screen, isNot(contains('AppAnalytics.track')));
  });

  test('SI V2 surface exposes the complete inspectable response contract', () {
    final String screen = File(
      'lib/features/si_console/ui/si_console_screen.dart',
    ).readAsStringSync();
    final String contract = File(
      'lib/domain/entities/si_v2_contract.dart',
    ).readAsStringSync();

    for (final String section in <String>[
      'DIRECT ANSWER',
      'OBSERVED FACTS',
      'DETERMINISTIC CALCULATIONS',
      'INFERENCES',
      'MISSING OR CONFLICTING INFORMATION',
      'SCENARIO ASSUMPTIONS',
      'RECOMMENDATION',
      'CONFIDENCE ANATOMY',
      'EVIDENCE LINKS',
    ]) {
      expect(screen, contains(section), reason: section);
    }
    expect(screen, contains('SI V2 QUERY BUILDER'));
    expect(screen, contains('SIV2Intent.values'));
    expect(screen, contains('SIV2Source.values'));
    expect(screen, contains('SIV2TimeRange.values'));
    expect(contract, isNot(contains('confidencePercent')));
    expect(contract, contains('coveredSignals'));
    expect(contract, contains('requiredSignals'));
  });
}
