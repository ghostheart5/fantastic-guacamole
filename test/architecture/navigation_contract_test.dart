import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String readAllLib() {
    final root = Directory('lib');
    final buffer = StringBuffer();

    if (!root.existsSync()) return '';

    for (final entity in root.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        buffer.writeln(entity.path);
        buffer.writeln(entity.readAsStringSync());
      }
    }

    return buffer.toString();
  }

  test('ChronoSpark navigation routes through Nexus Action Hub only', () {
    final lib = readAllLib();

    expect(
      lib.contains('BottomNavigationBar('),
      isFalse,
      reason:
          'BottomNavigationBar found. Navigation should route through Nexus Action Hub.',
    );

    expect(
      lib.contains('NavigationBar('),
      isFalse,
      reason:
          'Material NavigationBar found. ChronoSpark should not use bottom nav shell.',
    );

    expect(
      lib.contains('NavigationDestination('),
      isFalse,
      reason:
          'NavigationDestination found. Action Hub should own destinations.',
    );
  });

  test(
    'Action Hub required destinations are represented somewhere in app code',
    () {
      final lib = readAllLib();

      final required = <String>[
        'Coach',
        'Creator',
        'Timeline',
        'Profile',
        'Progression',
        'Trajectory',
        'SI Console',
      ];

      final missing = required.where((label) => !lib.contains(label)).toList();

      expect(
        missing,
        isEmpty,
        reason: 'Missing Action Hub destination labels or references: $missing',
      );
    },
  );

  test('internal engine concepts are not standalone public screens', () {
    final lib = readAllLib();

    final forbidden = <String>[
      'MemoriesScreen',
      'MemoryScreen',
      'InsightsScreen',
      'InsightScreen',
      'FlowMapScreen',
      'FlowmapScreen',
    ];

    final found = forbidden.where(lib.contains).toList();

    expect(
      found,
      isEmpty,
      reason:
          'Internal engine concepts should not be standalone screens: $found',
    );
  });
}
