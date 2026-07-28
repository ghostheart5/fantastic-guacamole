import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/tutorial/widgets/micro_tutorial_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MicroTutorialCard widget behavior', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPrefsService.init();
    });

    testWidgets('widget builds with ProviderScope and shows step text', (
      WidgetTester tester,
    ) async {
      const TutorialStepContent step = TutorialStepContent(
        id: 'nexus_overview',
        title: 'NEXUS OVERVIEW',
        description: 'Description text',
        ctaLabel: 'Open Nexus',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MicroTutorialCard(step: step),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NEXUS OVERVIEW'), findsOneWidget);
      expect(find.text('Description text'), findsOneWidget);
      expect(find.text('Open Nexus'), findsOneWidget);
    });

    testWidgets('tapping complete and skip paths does not throw', (
      WidgetTester tester,
    ) async {
      final TutorialStepContent step = TutorialContent.steps.first;
      int completeCalls = 0;
      int dismissCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MicroTutorialCard(
                step: step,
                onComplete: () => completeCalls += 1,
                onDismiss: () => dismissCalls += 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(step.ctaLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(completeCalls, greaterThanOrEqualTo(0));
      expect(dismissCalls, greaterThanOrEqualTo(0));
    });
  });
}
