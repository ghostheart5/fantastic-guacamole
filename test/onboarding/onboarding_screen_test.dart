import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/features/onboarding/domain/onboarding_content_contract.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('welcome completes before the optional first-value step', (
    WidgetTester tester,
  ) async {
    _setLargeTestSurface(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(_TestProfileController.new),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('onboarding-test-user'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('CHRONOSPARK'), findsOneWidget);
    expect(find.text('SKIP'), findsNothing);
    await tester.tap(find.text('Continue to login'));
    await tester.pump(const Duration(milliseconds: 300));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingWelcomeCompleteStorageKey), isTrue);
    expect(prefs.getBool(onboardingCompleteStorageKey), isNot(true));
    expect(container.read(onboardingWelcomeCompleteProvider), isTrue);
    expect(container.read(onboardingCompleteProvider), isFalse);
  });

  testWidgets('first-value question and capacity check-in are optional', (
    WidgetTester tester,
  ) async {
    _setLargeTestSurface(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      onboardingWelcomeCompleteStorageKey: true,
    });
    final ProviderContainer container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(_TestProfileController.new),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('onboarding-test-user'),
        ),
      ],
    );
    container.read(onboardingWelcomeCompleteProvider.notifier).set(true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('first-value-question')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('WHAT WOULD HELP RIGHT NOW?'), findsOneWidget);
    expect(find.text('CURRENT CAPACITY · OPTIONAL'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Steady'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);

    final FilledButton guideButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'SHOW ONE HELPFUL CHOICE'),
    );
    expect(guideButton.onPressed, isNotNull);
    expect(find.text('SKIP FOR NOW'), findsOneWidget);
  });

  testWidgets('first-value completion persists and stages ephemeral input', (
    WidgetTester tester,
  ) async {
    _setLargeTestSurface(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      onboardingWelcomeCompleteStorageKey: true,
    });
    final ProviderContainer container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(_TestProfileController.new),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('onboarding-test-user'),
        ),
      ],
    );
    container.read(onboardingWelcomeCompleteProvider.notifier).set(true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byType(TextField),
      'I feel overloaded and need one realistic next step.',
    );
    await tester.pump();
    await tester.tap(find.text('Low'));
    await tester.pump();
    await tester.tap(find.text('SHOW ONE HELPFUL CHOICE'));
    await tester.pump(const Duration(milliseconds: 600));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingCompleteStorageKey), isTrue);
    expect(
      prefs.getInt(onboardingContentVersionStorageKey),
      OnboardingContentContract.currentVersion,
    );
    expect(container.read(onboardingCompleteProvider), isTrue);
    final SmartPlannerFirstValueRequest? request = container.read(
      smartPlannerFirstValueProvider,
    );
    expect(request, isNotNull);
    expect(
      request!.prompt,
      'I feel overloaded and need one realistic next step.',
    );
    expect(request.energy, .3);
    expect(
      request.accountScopeId,
      AccountStorageScope.authenticated('onboarding-test-user').v2Namespace,
    );
  });

  testWidgets('skip completes setup without staging guidance', (
    WidgetTester tester,
  ) async {
    _setLargeTestSurface(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      onboardingWelcomeCompleteStorageKey: true,
    });
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('onboarding-test-user'),
        ),
      ],
    );
    container.read(onboardingWelcomeCompleteProvider.notifier).set(true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('SKIP FOR NOW'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(container.read(onboardingCompleteProvider), isTrue);
    expect(container.read(smartPlannerFirstValueProvider), isNull);
  });

  testWidgets('missing account scope cannot falsely complete first setup', (
    WidgetTester tester,
  ) async {
    _setLargeTestSurface(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      onboardingWelcomeCompleteStorageKey: true,
    });
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          const AccountStorageScope.signedOut(),
        ),
      ],
    );
    container.read(onboardingWelcomeCompleteProvider.notifier).set(true);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('SHOW ONE HELPFUL CHOICE'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingCompleteStorageKey), isNot(true));
    expect(prefs.getInt(onboardingContentVersionStorageKey), isNull);
    expect(container.read(onboardingCompleteProvider), isFalse);
    expect(container.read(smartPlannerFirstValueProvider), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('Unable to finish onboarding. Please try again.'),
      findsOneWidget,
    );
    final FilledButton guideButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'SHOW ONE HELPFUL CHOICE'),
    );
    expect(guideButton.onPressed, isNotNull);
  });

  testWidgets('stops decorative onboarding motion under reduced motion', (
    WidgetTester tester,
  ) async {
    _setLargeTestSurface(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(_TestProfileController.new),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('onboarding-test-user'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: OnboardingScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final Lottie lottie = tester.widget<Lottie>(find.byType(Lottie).first);
    expect(lottie.animate, isFalse);
    expect(lottie.repeat, isFalse);
  });
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();

  @override
  Future<void> updateName(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isNotEmpty) state = state.copyWith(name: trimmed);
  }
}

void _setLargeTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2560);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
