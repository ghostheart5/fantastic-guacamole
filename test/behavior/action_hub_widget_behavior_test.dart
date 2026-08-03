import 'dart:io';

import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Action Hub structural behavior', () {
    testWidgets('smart planner action tap transitions app flow to coach surface', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SmartPressable(
                onTap: () =>
                    container.read(appFlowProvider.notifier).toSmartCoach(),
                child: const Text('Smart Planner'),
              ),
            ),
          ),
        ),
      );

      expect(container.read(appFlowProvider), AppView.nexus);

      await tester.tap(find.text('Smart Planner'));
      await tester.pumpAndSettle();

      expect(container.read(appFlowProvider), AppView.smartCoach);
    });

    test('Nexus source retains explicit screen contract', () {
      final File file = File('lib/features/nexus/ui/nexus_screen.dart');
      expect(file.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(file);
      expect(text.contains('class NexusScreen extends ConsumerStatefulWidget'), isTrue);
      expect(text.contains('class _NexusScreenState'), isTrue);
      expect(text.contains('AnimatedSystemBackground'), isTrue);
    });

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
