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
    final String screen = <String>[
      'lib/features/si_console/ui/si_console_screen.dart',
      'lib/features/si_console/ui/si_console_screen.widgets.dart',
    ].map((String path) => File(path).readAsStringSync()).join('\n');

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
    final String screen = <String>[
      'lib/features/si_console/ui/si_console_screen.dart',
      'lib/features/si_console/ui/si_console_screen.widgets.dart',
    ].map((String path) => File(path).readAsStringSync()).join('\n');
    final String contract = File(
      'lib/domain/entities/si_v2_contract.dart',
    ).readAsStringSync();
    final String localizations = File(
      'lib/l10n/chronospark_localizations.dart',
    ).readAsStringSync();

    for (final ({String property, String englishLabel}) section
        in <({String property, String englishLabel})>[
          (property: 'directAnswer', englishLabel: 'DIRECT ANSWER'),
          (property: 'observedFacts', englishLabel: 'OBSERVED FACTS'),
          (
            property: 'deterministicCalculations',
            englishLabel: 'DETERMINISTIC CALCULATIONS',
          ),
          (property: 'inferences', englishLabel: 'INFERENCES'),
          (
            property: 'missingOrConflicting',
            englishLabel: 'MISSING OR CONFLICTING INFORMATION',
          ),
          (
            property: 'scenarioAssumptions',
            englishLabel: 'SCENARIO ASSUMPTIONS',
          ),
          (property: 'recommendation', englishLabel: 'RECOMMENDATION'),
          (property: 'confidenceAnatomy', englishLabel: 'CONFIDENCE ANATOMY'),
          (property: 'evidenceLinks', englishLabel: 'EVIDENCE LINKS'),
        ]) {
      expect(screen, contains('copy.${section.property}'));
      expect(
        localizations,
        contains("'${section.englishLabel}'"),
        reason: section.englishLabel,
      );
    }
    expect(screen, contains('copy.queryBuilder'));
    expect(localizations, contains("'SI V2 QUERY BUILDER'"));
    expect(screen, contains('SIV2Intent.values'));
    expect(screen, contains('SIV2Source.values'));
    expect(screen, contains('SIV2TimeRange.values'));
    expect(contract, isNot(contains('confidencePercent')));
    expect(contract, contains('coveredSignals'));
    expect(contract, contains('requiredSignals'));
  });
}
