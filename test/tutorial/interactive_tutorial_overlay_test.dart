import 'package:fantastic_guacamole/tutorial/interactive_tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('defers spotlight geometry for a transient zero-sized viewport', (
    WidgetTester tester,
  ) async {
    final GlobalKey targetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.shrink(
            child: Stack(
              children: <Widget>[
                SizedBox(key: targetKey),
                InteractiveTutorialOverlay(
                  targetKey: targetKey,
                  title: 'Deferred guide',
                  body: 'Waits for usable layout constraints.',
                  primaryLabel: 'Next',
                  onPrimary: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Deferred guide'), findsNothing);
  });

  testWidgets('fits the tutorial callout inside a compact viewport', (
    WidgetTester tester,
  ) async {
    final GlobalKey targetKey = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(240, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(key: targetKey, width: 80, height: 40),
              ),
              InteractiveTutorialOverlay(
                targetKey: targetKey,
                title: 'Compact guide',
                body: 'The guide remains readable without overflowing.',
                primaryLabel: 'Next',
                onPrimary: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Compact guide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spotlight keeps the real target and guide action interactive', (
    WidgetTester tester,
  ) async {
    final GlobalKey targetKey = GlobalKey();
    int targetTaps = 0;
    int guideTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Center(
                child: FilledButton(
                  key: targetKey,
                  onPressed: () => targetTaps += 1,
                  child: const Text('REAL CONTROL'),
                ),
              ),
              InteractiveTutorialOverlay(
                targetKey: targetKey,
                stepLabel: 'Step 1 of 1',
                title: 'Use the real control',
                body: 'The highlighted control remains active.',
                primaryLabel: 'Next',
                onPrimary: () => guideTaps += 1,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
    expect(find.text('Use the real control'), findsOneWidget);

    await tester.tap(find.text('REAL CONTROL'));
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();

    expect(targetTaps, 1);
    expect(guideTaps, 1);
    expect(tester.takeException(), isNull);
  });
}
