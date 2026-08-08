import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the name field on the personalization step stays visible above a '
    'simulated software keyboard',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
      );
      await tester.pump();

      // The starfield background repeats an AnimationController forever, so
      // pumpAndSettle would never converge. A single large pump can also
      // land mid-transition for the PageController-driven scroll, so settle
      // the 400ms page-turn animation with several smaller steps instead.
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('NEXT'));
        for (int step = 0; step < 10; step++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      final Finder nameField = find.byType(TextField);
      expect(nameField, findsOneWidget);

      await tester.tap(nameField);
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      for (int step = 0; step < 10; step++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final Rect fieldRect = tester.getRect(find.byType(TextField));
      final double visibleBottom =
          tester.view.physicalSize.height / tester.view.devicePixelRatio -
          300;

      expect(fieldRect.bottom, lessThanOrEqualTo(visibleBottom));
    },
  );
}
