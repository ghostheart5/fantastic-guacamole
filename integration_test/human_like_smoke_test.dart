import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fantastic_guacamole/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> tapFirstOrThrow(
    WidgetTester tester,
    List<Finder> candidates,
    String stepLabel,
  ) async {
    for (final Finder candidate in candidates) {
      if (candidate.evaluate().isNotEmpty) {
        await tester.tap(candidate.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        return;
      }
    }
    fail('Could not find target for step: $stepLabel');
  }

  Future<void> openGoalsTabIfPresent(WidgetTester tester) async {
    final goalsTabCandidates = [
      find.text('Goals'),
      find.text('GOALS'),
      find.byTooltip('Goals'),
    ];

    for (final candidate in goalsTabCandidates) {
      if (candidate.evaluate().isNotEmpty) {
        await tester.tap(candidate.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        return;
      }
    }
  }

  Future<void> openSettingsTabOrThrow(WidgetTester tester) async {
    await tapFirstOrThrow(tester, <Finder>[
      find.text('Settings'),
      find.text('SETTINGS'),
      find.byTooltip('Settings'),
    ], 'open settings');
  }

  group('ChronoSpark human-like smoke', () {
    testWidgets('launch app and remain exception-free', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });

    testWidgets('open Smart Planner and back returns safely', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tapFirstOrThrow(tester, <Finder>[
        find.text('Smart Planner'),
        find.text('Coach'),
        find.byTooltip('Smart Planner'),
      ], 'open smart planner');

      final Finder coachBackButton = find.byKey(
        const Key('smart_coach_back_button'),
      );
      expect(coachBackButton, findsOneWidget);

      await tester.tap(coachBackButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byKey(const Key('smart_coach_back_button')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('create goal flow with stable keys', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await openGoalsTabIfPresent(tester);

      final addButton = find.byKey(const Key('goals_add_button'));
      final titleInput = find.byKey(const Key('goal_title_input'));
      final saveButton = find.byKey(const Key('goal_save_button'));
      const smokeTitle = 'Smoke Task';

      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(titleInput, findsOneWidget);
      expect(saveButton, findsOneWidget);

      await tester.enterText(titleInput, smokeTitle);
      await tester.pumpAndSettle(const Duration(milliseconds: 250));

      await tester.tap(saveButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text(smokeTitle), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings dark mode toggle persists after restart', (
      tester,
    ) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await openSettingsTabOrThrow(tester);

      final Finder darkModeToggle = find.byKey(
        const Key('settings_dark_mode_toggle'),
      );
      expect(darkModeToggle, findsOneWidget);

      final bool initialValue =
          tester.widget<Switch>(darkModeToggle).value;

      await tester.tap(darkModeToggle);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final bool toggledValue =
          tester.widget<Switch>(darkModeToggle).value;
      expect(toggledValue, equals(!initialValue));

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await openSettingsTabOrThrow(tester);

      final Finder darkModeToggleAfterRestart = find.byKey(
        const Key('settings_dark_mode_toggle'),
      );
      expect(darkModeToggleAfterRestart, findsOneWidget);

      final bool persistedValue =
          tester.widget<Switch>(darkModeToggleAfterRestart).value;
      expect(persistedValue, equals(toggledValue));
      expect(tester.takeException(), isNull);
    });
  });
}
