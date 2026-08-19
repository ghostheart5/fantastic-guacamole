import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Nexus keeps the required schedule-first hierarchy', () {
    final String source = File(
      'lib/features/nexus/ui/nexus_screen.dart',
    ).readAsStringSync();
    final int header = source.indexOf('_NexusHeader(');
    final int schedule = source.indexOf('_NexusTimeBlockSchedule(');
    final int rings = source.indexOf('_SystemRings(');

    expect(header, greaterThanOrEqualTo(0));
    expect(schedule, greaterThan(header));
    expect(rings, greaterThan(schedule));
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
      'Plan View',
      'OPEN PLAN',
    ]) {
      expect(source, isNot(contains(retired)), reason: '$retired returned');
    }
  });
}
