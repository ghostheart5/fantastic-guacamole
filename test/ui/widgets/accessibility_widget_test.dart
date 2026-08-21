import 'dart:ui' show Tristate;

import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/ui/widgets/typing_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
}
