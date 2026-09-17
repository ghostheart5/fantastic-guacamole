import 'package:fantastic_guacamole/features/assistant/ui/assistant_response_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reply = '''**The shorter trip fits.**

| Detail | Saved task | Hypothetical |
|---|---|---|
| Duration | 45 minutes | 20 minutes |
| Return | 7:15 pm | 6:50 pm |

- Keep the saved task unchanged.
''';
  for (final width in [320.0, 412.0]) {
    testWidgets('live comparison is formatted at width $width and large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 915),
                textScaler: const TextScaler.linear(2),
              ),
              child: const SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: AssistantResponseBody(text: reply),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('45 minutes', findRichText: true), findsWidgets);
      expect(find.text('**The shorter trip fits.**'), findsNothing);
      expect(find.byType(SelectionArea), findsOneWidget);
      final heading = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere(
            (widget) => widget.text.toPlainText() == 'The shorter trip fits.',
          );
      final weights = <FontWeight?>[heading.text.style?.fontWeight];
      heading.text.visitChildren((span) {
        weights.add(span.style?.fontWeight);
        return true;
      });
      expect(weights, contains(FontWeight.bold));
      final horizontal = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      expect(horizontal, findsOneWidget);
      await tester.drag(horizontal, const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SingleChildScrollView>(horizontal).controller!.offset,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('model images cannot fetch network or local content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantResponseBody(
            text:
                '![Network image](https://example.invalid/tracker.png)\n\n![Local image](file:///private.png)\n\n[Store](https://example.invalid)',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Network image'), findsOneWidget);
    expect(find.text('Local image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
