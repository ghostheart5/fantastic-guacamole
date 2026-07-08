import 'package:fantastic_guacamole/ui/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows message and retry action when callback is provided', (
    WidgetTester tester,
  ) async {
    int taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorView(
            title: 'Data Error',
            message: 'Could not load mission context.',
            onRetry: () {
              taps += 1;
            },
          ),
        ),
      ),
    );

    expect(find.text('Data Error'), findsOneWidget);
    expect(find.text('Could not load mission context.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(taps, 1);
  });
}
