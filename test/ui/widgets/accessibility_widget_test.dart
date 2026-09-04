import 'dart:ui' show Tristate;

import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/ui/widgets/typing_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TypingText exposes a stable semantics label', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingText(
              'System calibration complete',
              animate: true,
              step: Duration(days: 1),
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('System calibration complete'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'HoloButton keeps at least 48dp touch target and button semantics',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HoloButton(label: 'Launch', onTap: () {}),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(HoloButton));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(find.bySemanticsLabel('Launch'), findsOneWidget);
        final SemanticsNode node = tester.getSemantics(
          find.bySemanticsLabel('Launch'),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('disabled HoloButton announces disabled and has no tap action', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HoloButton(label: 'Thinking')),
        ),
      );

      final SemanticsData data = tester
          .getSemantics(find.bySemanticsLabel('Thinking'))
          .getSemanticsData();
      expect(data.flagsCollection.isEnabled, isNot(Tristate.none));
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('SmartPressable semantic node retains an invokable tap action', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartPressable(
              semanticLabel: 'Open evidence',
              onTap: () {},
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      );

      final SemanticsData data = tester
          .getSemantics(find.bySemanticsLabel('Open evidence'))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('SmartPressable activates from keyboard focus', (
    WidgetTester tester,
  ) async {
    int activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartPressable(
            semanticLabel: 'Keyboard action',
            onTap: () => activations += 1,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(activations, 1);
  });

  testWidgets(
    'SmartPressable skips disabled controls and preserves keyboard order',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final List<String> activations = <String>[];
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: <Widget>[
                  SmartPressable(
                    semanticLabel: 'Unavailable action',
                    enabled: false,
                    onTap: () => activations.add('disabled'),
                    child: const SizedBox(width: 48, height: 48),
                  ),
                  SmartPressable(
                    semanticLabel: 'First action',
                    onTap: () => activations.add('first'),
                    child: const SizedBox(width: 48, height: 48),
                  ),
                  SmartPressable(
                    semanticLabel: 'Second action',
                    onTap: () => activations.add('second'),
                    child: const SizedBox(width: 48, height: 48),
                  ),
                ],
              ),
            ),
          ),
        );

        final SemanticsData disabledData = tester
            .getSemantics(find.bySemanticsLabel('Unavailable action'))
            .getSemanticsData();
        expect(disabledData.flagsCollection.isEnabled, Tristate.isFalse);
        expect(disabledData.hasAction(SemanticsAction.tap), isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);

        expect(activations, <String>['first', 'second']);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('SmartPressable skips press animation when motion is reduced', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SmartPressable(
              semanticLabel: 'Reduced motion action',
              onTap: () {},
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Reduced motion action'));
    await tester.pump();

    expect(tester.binding.transientCallbackCount, 0);
  });
}
