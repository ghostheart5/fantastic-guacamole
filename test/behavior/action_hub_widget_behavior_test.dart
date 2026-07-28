import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Action Hub structural behavior', () {
    test('Nexus action surfaces include required user destinations', () {
      final File file = File('lib/features/nexus/ui/nexus_screen.widgets.dart');
      expect(file.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(file);
      const List<List<String>> requiredLabels = <List<String>>[
        <String>['Smart Planner', 'Coach'],
        <String>['Creator'],
        <String>['Timeline'],
        <String>['Profile'],
        <String>['Progression', 'Ascension'],
        <String>['Trajectory', 'Future Vector'],
      ];

      for (final List<String> labelVariants in requiredLabels) {
        final bool hasVariant = labelVariants.any(
          (String label) => text.contains("label: '$label'"),
        );
        expect(
          hasVariant,
          isTrue,
          reason: 'Expected action destination not found: ${labelVariants.join(' / ')}',
        );
      }
      expect(text.contains('toConsole('), isTrue);
    });

    test('Action surfaces do not expose internal engines as standalone destinations', () {
      final File file = File('lib/features/nexus/ui/nexus_screen.widgets.dart');
      expect(file.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(file);
      const List<String> forbiddenLabels = <String>[
        "label: 'Memories'",
        "label: 'Insights'",
        "label: 'FlowMap'",
      ];

      for (final String token in forbiddenLabels) {
        expect(
          text.contains(token),
          isFalse,
          reason: 'Forbidden standalone destination found: $token',
        );
      }
    });

    test('Action destinations are wired to app flow transitions', () {
      final File file = File('lib/features/nexus/ui/nexus_screen.widgets.dart');
      final String text = SourceTestUtils.readText(file);

      const List<String> requiredActions = <String>[
        'toSmartCoach()',
        'toCreator()',
        'toTimeline()',
        'toProfile()',
        'toProgression()',
        'toTrajectoryEngine()',
        'toConsole()',
      ];

      for (final String action in requiredActions) {
        expect(
          text.contains(action),
          isTrue,
          reason: 'Missing expected action flow transition: $action',
        );
      }
    });
  });
}
