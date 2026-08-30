import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/features/onboarding/domain/onboarding_content_contract.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('welcome completes before account profile setup', (
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

  testWidgets('name setup is focused and requires user input', (
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

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('PRIMARY GOAL'), findsNothing);
    expect(find.text('Personal Growth'), findsNothing);

    final FilledButton guideButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue to Creator'),
    );
    expect(guideButton.onPressed, isNull);
  });

  testWidgets('name completion persists profile and starts core setup', (
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

    await tester.enterText(find.byType(TextField), 'Keegan');
    await tester.pump();
    await tester.tap(find.text('Continue to Creator'));
    await tester.pump(const Duration(milliseconds: 600));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingCompleteStorageKey), isTrue);
    expect(
      prefs.getInt(onboardingContentVersionStorageKey),
      OnboardingContentContract.currentVersion,
    );
    expect(container.read(profileProvider).name, 'Keegan');
    expect(container.read(onboardingCompleteProvider), isTrue);
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
