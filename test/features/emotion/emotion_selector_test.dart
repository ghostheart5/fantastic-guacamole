import 'package:fantastic_guacamole/features/emotion/widgets/emotion_selector.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('updates selected chip style and triggers onSelect callback', (
    tester,
  ) async {
    EmotionalState selected = EmotionalState.focused;
    EmotionalState? callbackValue;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: EmotionSelector(
                selected: selected,
                onSelect: (value) {
                  callbackValue = value;
                  setState(() {
                    selected = value;
                  });
                },
              ),
            );
          },
        ),
      ),
    );

    final Text focusedBefore = tester.widget<Text>(find.text('FOCUSED'));
    final Text anxiousBefore = tester.widget<Text>(find.text('ANXIOUS'));

    expect(focusedBefore.style?.color, AppColors.neonViolet);
    expect(anxiousBefore.style?.color, Colors.white38);

    await tester.tap(find.text('ANXIOUS'));
    await tester.pumpAndSettle();

    expect(callbackValue, EmotionalState.anxious);

    final Text focusedAfter = tester.widget<Text>(find.text('FOCUSED'));
    final Text anxiousAfter = tester.widget<Text>(find.text('ANXIOUS'));

    expect(focusedAfter.style?.color, Colors.white38);
    expect(anxiousAfter.style?.color, AppColors.recallRed);
  });

  testWidgets('renders one chip for every EmotionalState value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmotionSelector(
            selected: EmotionalState.neutral,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    for (final state in EmotionalState.values) {
      expect(find.text(state.name.toUpperCase()), findsOneWidget);
    }
  });
}
