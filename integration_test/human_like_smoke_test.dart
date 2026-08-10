import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fantastic_guacamole/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFor(
    WidgetTester tester,
    Duration duration, {
    Duration step = const Duration(milliseconds: 100),
  }) async {
    final int steps = (duration.inMilliseconds / step.inMilliseconds).ceil();
    for (int i = 0; i < steps; i++) {
      await tester.pump(step);
    }
  }

  Future<Finder?> waitForFirst(
    WidgetTester tester,
    List<Finder> candidates, {
    Duration timeout = const Duration(seconds: 5),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final Finder candidate in candidates) {
        if (candidate.evaluate().isNotEmpty) {
          return candidate.first;
        }
      }
      await tester.pump(step);
    }
    return null;
  }

  Future<void> waitUntilGone(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 4),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (finder.evaluate().isEmpty) {
        return;
      }
      await tester.pump(step);
    }

    fail('Timed out waiting for widget to disappear: $finder');
  }

  Future<void> completeOnboardingIfPresent(WidgetTester tester) async {
    // Advance onboarding if currently shown.
    for (int i = 0; i < 3; i++) {
      final Finder? skip = await waitForFirst(tester, <Finder>[
        find.text('SKIP'),
      ], timeout: const Duration(seconds: 1));
      if (skip != null) {
        await tester.tap(skip);
        await pumpFor(tester, const Duration(seconds: 2));
        return;
      }

      final Finder? startSetup = await waitForFirst(tester, <Finder>[
        find.text('START SETUP'),
      ], timeout: const Duration(seconds: 1));
      if (startSetup != null) {
        await tester.tap(startSetup);
        await pumpFor(tester, const Duration(seconds: 2));
        return;
      }

      final Finder? next = await waitForFirst(tester, <Finder>[
        find.text('NEXT'),
      ], timeout: const Duration(seconds: 1));
      if (next == null) {
        return;
      }
      await tester.tap(next);
      await pumpFor(tester, const Duration(milliseconds: 900));
    }
  }

  group('ChronoSpark human-like smoke', () {
    testWidgets('smoke flows complete on a single app boot', (tester) async {
      app.main();
      await pumpFor(tester, const Duration(seconds: 5));
      await completeOnboardingIfPresent(tester);
      await pumpFor(tester, const Duration(seconds: 1));

      final Finder? plannerEntry = await waitForFirst(tester, <Finder>[
        find.text('Smart Planner'),
        find.text('Coach'),
        find.byTooltip('Smart Planner'),
      ], timeout: const Duration(seconds: 4));

      if (plannerEntry != null) {
        await tester.tap(plannerEntry);
        await pumpFor(tester, const Duration(seconds: 1));

        final Finder? resolvedBackButton = await waitForFirst(tester, <Finder>[
          find.byKey(const Key('smart_coach_back_button')),
        ], timeout: const Duration(seconds: 3));
        expect(resolvedBackButton, isNotNull);
        await tester.tap(resolvedBackButton!);
        await pumpFor(tester, const Duration(seconds: 1));
        await waitUntilGone(
          tester,
          find.byKey(const Key('smart_coach_back_button')),
        );
      }

      final Finder? addButton = await waitForFirst(tester, <Finder>[
        find.byKey(const Key('goals_add_button')),
      ], timeout: const Duration(seconds: 4));
      if (addButton != null) {
        const String smokeTitle = 'Smoke Task';
        await tester.tap(addButton);
        await pumpFor(tester, const Duration(milliseconds: 600));

        final Finder? titleInput = await waitForFirst(tester, <Finder>[
          find.byKey(const Key('goal_title_input')),
        ], timeout: const Duration(seconds: 3));
        final Finder? saveButton = await waitForFirst(tester, <Finder>[
          find.byKey(const Key('goal_save_button')),
        ], timeout: const Duration(seconds: 3));
        expect(titleInput, isNotNull);
        expect(saveButton, isNotNull);

        await tester.enterText(titleInput!, smokeTitle);
        await pumpFor(tester, const Duration(milliseconds: 250));
        await tester.tap(saveButton!);
        await pumpFor(tester, const Duration(seconds: 1));

        expect(find.text(smokeTitle), findsWidgets);
      }

      final Finder? settingsEntry = await waitForFirst(tester, <Finder>[
        find.text('Settings'),
        find.text('SETTINGS'),
        find.byTooltip('Settings'),
      ], timeout: const Duration(seconds: 4));
      if (settingsEntry != null) {
        await tester.tap(settingsEntry);
        await pumpFor(tester, const Duration(milliseconds: 600));

        final Finder? darkModeToggle = await waitForFirst(tester, <Finder>[
          find.byKey(const Key('settings_dark_mode_toggle')),
        ], timeout: const Duration(seconds: 3));
        expect(darkModeToggle, isNotNull);

        final bool initialValue = tester.widget<Switch>(darkModeToggle!).value;
        await tester.tap(darkModeToggle);
        await pumpFor(tester, const Duration(seconds: 1));

        final bool toggledValue = tester.widget<Switch>(darkModeToggle).value;
        expect(toggledValue, equals(!initialValue));

        app.main();
        await pumpFor(tester, const Duration(seconds: 5));
        await completeOnboardingIfPresent(tester);
        await pumpFor(tester, const Duration(seconds: 1));

        final Finder? darkModeToggleAfterRestart = await waitForFirst(
          tester,
          <Finder>[find.byKey(const Key('settings_dark_mode_toggle'))],
          timeout: const Duration(seconds: 3),
        );
        expect(darkModeToggleAfterRestart, isNotNull);
        final bool persistedValue = tester
            .widget<Switch>(darkModeToggleAfterRestart!)
            .value;
        expect(persistedValue, equals(toggledValue));
      }

      expect(tester.takeException(), isNull);
    });
  });
}
