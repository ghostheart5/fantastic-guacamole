import 'package:fantastic_guacamole/tutorial/interactive_tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
