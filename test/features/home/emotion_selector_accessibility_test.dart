import 'dart:ui' show Tristate;

import 'package:fantastic_guacamole/features/emotion/widgets/emotion_selector.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all emotion choices expose selected state and 48dp targets', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: EmotionSelector(
                  selected: EmotionalState.anxious,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SmartPressable), findsNWidgets(9));
      for (final EmotionalState state in EmotionalState.values) {
        final Finder choice = find.bySemanticsLabel(
          'Select ${state.name} emotional state',
        );
        expect(choice, findsOneWidget);
        final SemanticsData data = tester
            .getSemantics(choice)
            .getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(
          data.flagsCollection.isSelected == Tristate.isTrue,
          state == EmotionalState.anxious,
        );
      }
      for (final Element element in find.byType(SmartPressable).evaluate()) {
        final Size size = tester.getSize(find.byWidget(element.widget));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    } finally {
      semantics.dispose();
    }
  });
}
