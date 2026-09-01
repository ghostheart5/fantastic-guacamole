import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the optional first-value question stays visible above a '
      'simulated software keyboard', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ProviderContainer container = ProviderContainer();
    container.read(onboardingWelcomeCompleteProvider.notifier).set(true);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();

    final Finder helpField = find.byKey(const Key('first-value-question'));
    expect(helpField, findsOneWidget);

    await tester.tap(helpField);
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    for (int step = 0; step < 10; step++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final Rect fieldRect = tester.getRect(helpField);
    final double visibleBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio - 300;

    expect(fieldRect.bottom, lessThanOrEqualTo(visibleBottom));
  });
}
