import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Navigation and Action Hub release protection', () {
    test('navigation shell exists and includes required destinations', () {
      final File shell = File('lib/app/navigation_shell.dart');
      expect(shell.existsSync(), isTrue);
      final String text = SourceTestUtils.readText(shell);

      const List<String> requiredSymbols = <String>[
        'CreatorScreen',
        'TimelineScreen',
        'ProfileScreen',
        'NexusScreen',
        'SmartCoachScreen',
        'ProgressionScreen',
        'TrajectoryEngineScreen',
        'SIConsoleScreen',
      ];

      for (final String symbol in requiredSymbols) {
        expect(
          text.contains(symbol),
          isTrue,
          reason: 'Missing required navigation destination: $symbol',
        );
      }
    });

    test('forbidden internal engine standalone screens are absent', () {
      final String libText = SourceTestUtils.readAllConcatenated('lib');
      expect(libText.contains('class MemoriesScreen'), isFalse);
      expect(libText.contains('class InsightsScreen'), isFalse);
      expect(libText.contains('class FlowMapScreen'), isFalse);
    });

    test('bottom nav widgets are not used in production lib', () {
      final String libText = SourceTestUtils.readAllConcatenated('lib');
      expect(libText.contains('BottomNavigationBar('), isFalse);
      expect(libText.contains('NavigationBar('), isFalse);
      expect(libText.contains('NavigationDestination('), isFalse);
    });

    test('route identifiers include creator timeline and si console', () {
      final File routePaths = File('lib/app/router/route_paths.dart');
      expect(routePaths.existsSync(), isTrue);
      final String text = SourceTestUtils.readText(routePaths).toLowerCase();

      expect(text.contains('creator'), isTrue);
      expect(text.contains('timeline'), isTrue);
      expect(text.contains('si'), isTrue);
    });
  });
}
