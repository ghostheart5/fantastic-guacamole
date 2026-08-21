import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Nexus keeps the required dashboard hierarchy', () {
    final String source = File(
      'lib/features/nexus/ui/nexus_screen.dart',
    ).readAsStringSync();
    final int header = source.indexOf('_NexusHeader(');
    final int rings = source.indexOf('_NexusVitals(');
    final int suggestion = source.indexOf('_SmartPlannerSuggestion(');
    final int focus = source.indexOf('_CurrentFocusSection(');
    final int trajectory = source.indexOf('_TrajectoryReport(');
    final int timeline = source.indexOf('_TimelineSnapshot(');

    expect(header, greaterThanOrEqualTo(0));
    expect(rings, greaterThan(header));
    expect(suggestion, greaterThan(rings));
    expect(focus, greaterThan(suggestion));
    expect(trajectory, greaterThan(focus));
    expect(timeline, greaterThan(trajectory));
  });

  test('retired Nexus dashboard and Plan View do not return', () {
    final String source = <String>[
      File('lib/features/nexus/ui/nexus_screen.dart').readAsStringSync(),
      File(
        'lib/features/nexus/ui/nexus_screen.widgets.dart',
      ).readAsStringSync(),
    ].join('\n');

    for (final String retired in <String>[
      'NexusDecisionSection',
      'NexusFeatureSignalMesh',
      '_FirstRunCta',
      '_DependencyMesh',
      '_ActionGrid',
      '_NexusBridgeCard',
      '_NexusDestinationPanel',
      'Plan View',
      'OPEN PLAN',
    ]) {
      expect(source, isNot(contains(retired)), reason: '$retired returned');
    }
  });
}
