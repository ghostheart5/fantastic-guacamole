import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('skip marks onboarding complete', (WidgetTester tester) async {
    _setLargeTestSurface(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: [profileProvider.overrideWith(_TestProfileController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('SKIP'));
    await tester.pump(const Duration(milliseconds: 500));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingCompleteStorageKey), isTrue);
    expect(
      prefs.getInt(onboardingContentVersionStorageKey),
      TutorialContent.contentVersion,
    );
    expect(container.read(onboardingCompleteProvider), isTrue);
  });

  testWidgets('next progresses onboarding slides', (WidgetTester tester) async {
    _setLargeTestSurface(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileProvider.overrideWith(_TestProfileController.new)],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CHRONOSPARK'), findsOneWidget);
    await _tapPrimaryButton(tester, 'NEXT');
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('SMART COACH'), findsOneWidget);
  });

  testWidgets('personalization completion persists name and goal type', (
    WidgetTester tester,
  ) async {
    _setLargeTestSurface(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: [profileProvider.overrideWith(_TestProfileController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    for (int i = 0; i < 5; i++) {
      await _tapPrimaryButton(tester, 'NEXT');
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('YOUR MISSION'), findsOneWidget);

    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Enter your name...',
      ),
      'Keegan',
    );
    await tester.tap(find.text('Personal Growth'));
    await tester.pump(const Duration(milliseconds: 200));

    await _tapPrimaryButton(tester, 'INITIALIZE SYSTEM');
    await tester.pump(const Duration(milliseconds: 600));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingCompleteStorageKey), isTrue);
    expect(
      prefs.getInt(onboardingContentVersionStorageKey),
      TutorialContent.contentVersion,
    );
    expect(prefs.getString('primary_goal_type'), 'Personal Growth');
    expect(container.read(profileProvider).name, 'Keegan');
    expect(container.read(onboardingCompleteProvider), isTrue);
  });
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();
}

Future<void> _tapPrimaryButton(WidgetTester tester, String label) async {
  final Finder labelFinder = find.text(label);
  expect(labelFinder, findsOneWidget);
  final Finder buttonFinder = find
      .ancestor(of: labelFinder, matching: find.byType(GestureDetector))
      .first;
  await tester.tap(buttonFinder);
  await tester.pump();
}

void _setLargeTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2560);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
