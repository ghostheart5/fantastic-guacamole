import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('captures error and renders fallback with retry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ErrorBoundary(child: _ErrorTriggerWidget())),
    );

    expect(find.text('child-ready'), findsOneWidget);

    await Logger.withMutedErrors(() async {
      await tester.tap(find.text('trigger-error'));
      await tester.pump();
      await tester.pump();
    });

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('child-ready'), findsOneWidget);
    expect(find.text('Something went wrong'), findsNothing);
  });
}

class _ErrorTriggerWidget extends StatelessWidget {
  const _ErrorTriggerWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const Text('child-ready'),
          TextButton(
            onPressed: () {
              ErrorBoundary.of(context)?.captureError(StateError('test-error'));
            },
            child: const Text('trigger-error'),
          ),
        ],
      ),
    );
  }
}
