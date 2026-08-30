import 'package:fantastic_guacamole/tutorial/interactive_tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
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
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is AbsorbPointer && widget.absorbing,
      ),
      findsNothing,
    );
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
    final Rect callout = tester.getRect(
      find.byKey(const Key('tutorial_callout')),
    );
    expect(callout.left, greaterThanOrEqualTo(0));
    expect(callout.top, greaterThanOrEqualTo(0));
    expect(callout.right, lessThanOrEqualTo(240));
    expect(callout.bottom, lessThanOrEqualTo(400));
    expect(
      find.byKey(const Key('tutorial_callout_scroll_view')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text scrolls inside the bounded callout', (
    WidgetTester tester,
  ) async {
    final GlobalKey targetKey = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(280, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(key: targetKey, width: 80, height: 40),
              ),
              InteractiveTutorialOverlay(
                targetKey: targetKey,
                stepLabel: 'Step 1 of 2',
                title: 'Large text guide',
                body:
                    'This deliberately long explanation remains readable and '
                    'scrollable when the system text size is very large.',
                primaryLabel: 'Continue to the next tutorial step',
                secondaryLabel: 'Not now',
                onPrimary: () {},
                onSecondary: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final Finder scrollView = find.byKey(
      const Key('tutorial_callout_scroll_view'),
    );
    final Rect callout = tester.getRect(
      find.byKey(const Key('tutorial_callout')),
    );
    expect(callout.bottom, lessThanOrEqualTo(320));
    expect(
      tester.getSize(find.byKey(const Key('tutorial_callout_content'))).height,
      greaterThan(tester.getSize(scrollView).height),
    );
    await tester.drag(scrollView, const Offset(0, -300));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('announces the callout as a live modal dialog', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final GlobalKey targetKey = GlobalKey();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                Center(child: SizedBox(key: targetKey, width: 80, height: 40)),
                InteractiveTutorialOverlay(
                  targetKey: targetKey,
                  stepLabel: 'Step 1 of 1',
                  title: 'Semantic guide',
                  body: 'Announced when the tutorial step appears.',
                  primaryLabel: 'Continue',
                  onPrimary: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final SemanticsData data = tester
          .getSemantics(find.byKey(const Key('tutorial_callout_semantics')))
          .getSemanticsData();
      expect(data.role, SemanticsRole.dialog);
      expect(data.flagsCollection.scopesRoute, isTrue);
      expect(data.flagsCollection.namesRoute, isTrue);
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(data.label, 'Step 1 of 1. Semantic guide');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('modal callout focuses and activates its primary action by key', (
    WidgetTester tester,
  ) async {
    final GlobalKey targetKey = GlobalKey();
    int activations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Center(child: SizedBox(key: targetKey, width: 80, height: 40)),
              InteractiveTutorialOverlay(
                targetKey: targetKey,
                title: 'Keyboard guide',
                body: 'The primary action receives modal keyboard focus.',
                primaryLabel: 'Continue',
                onPrimary: () => activations += 1,
                allowTargetInteraction: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.focusNode?.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activations, 1);
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

  testWidgets('scrim preserves the deep-space screen identity', (
    WidgetTester tester,
  ) async {
    final GlobalKey targetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Center(child: SizedBox(key: targetKey, width: 80, height: 40)),
              InteractiveTutorialOverlay(
                targetKey: targetKey,
                title: 'Deep-space guide',
                body: 'The current screen remains visually recognizable.',
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

    final Iterable<ColoredBox> blockers = tester.widgetList<ColoredBox>(
      find.byType(ColoredBox),
    );
    expect(
      blockers.any((ColoredBox box) => box.color == const Color(0x94050D1A)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
