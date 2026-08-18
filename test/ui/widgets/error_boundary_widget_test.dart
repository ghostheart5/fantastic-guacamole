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

  testWidgets('redacts credentials from the rendered failure detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ErrorBoundary(child: _SensitiveErrorWidget())),
    );

    await Logger.withMutedErrors(() async {
      await tester.tap(find.text('trigger-sensitive-error'));
      await tester.pump();
      await tester.pump();
    });

    expect(find.textContaining('person@example.com'), findsNothing);
    expect(find.textContaining('super-secret'), findsNothing);
    expect(
      find.textContaining('ChronoSpark recovered the failure'),
      findsOneWidget,
    );
    expect(find.textContaining('[redacted-email]'), findsNothing);
    expect(find.textContaining('[redacted-password]'), findsNothing);
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

class _SensitiveErrorWidget extends StatelessWidget {
  const _SensitiveErrorWidget();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        ErrorBoundary.of(context)?.captureError(
          StateError('email=person@example.com password=super-secret'),
        );
      },
      child: const Text('trigger-sensitive-error'),
    );
  }
}
