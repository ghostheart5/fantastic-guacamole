import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'unavailable local storage blocks account access and allows retry',
    (WidgetTester tester) async {
      int startupAttempts = 0;
      int accountInitializations = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: StartupBootstrapGate(
            initializeStartup: (_, _) async {
              startupAttempts++;
              return const StartupBootstrapResult(
                hasOnboarded: false,
                hasSeenWelcome: false,
                startupError: 'Local storage could not be opened.',
                productionReadinessBlocked: false,
                localStorageUnavailable: true,
              );
            },
            initializeAccountBoundary: (_) async {
              accountInitializations++;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(startupAttempts, 1);
      expect(accountInitializations, 0);
      expect(find.text('Startup needs attention'), findsOneWidget);
      expect(
        find.textContaining('Local data could not be opened.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('Retry startup'));
      await tester.pumpAndSettle();
      expect(startupAttempts, 2);
      expect(accountInitializations, 0);
      expect(find.text('Retry startup'), findsOneWidget);
    },
  );
}
