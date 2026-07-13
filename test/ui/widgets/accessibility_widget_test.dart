import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:fantastic_guacamole/ui/widgets/typing_text.dart';
import 'package:flutter/material.dart';
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
      } finally {
        semantics.dispose();
      }
    },
  );
}
