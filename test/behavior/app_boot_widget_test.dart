import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App boot widget behavior', () {
    testWidgets('app root can be pumped inside ProviderScope', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: AppRoot()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(AppRoot), findsOneWidget);
    });

    testWidgets('incomplete first-run routing remains on onboarding', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(onboardingStatusProvider.notifier)
          .set(OnboardingStatus.incomplete);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const AppRoot()),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Route not found'), findsNothing);
      expect(find.bySemanticsIdentifier('screen-onboarding'), findsOneWidget);
      expect(find.bySemanticsIdentifier('onboarding-next'), findsOneWidget);
      expect(find.bySemanticsIdentifier('onboarding-skip'), findsOneWidget);
    });

    test(
      'Nexus entry screen widget is constructible for home surface contract',
      () {
        const Widget home = NexusScreen();
        expect(home, isA<NexusScreen>());
      },
    );
  });
}
