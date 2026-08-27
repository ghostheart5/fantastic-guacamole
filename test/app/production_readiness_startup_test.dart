import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('production readiness startup gate', () {
    test('blocks only enforced production startup with readiness issues', () {
      expect(
        Env.resolveShouldBlockStartupForProductionReadiness(
          enforceProductionReadiness: true,
          isProduction: true,
          readinessIssues: const <String>['Missing required setup.'],
        ),
        isTrue,
      );

      expect(
        Env.resolveShouldBlockStartupForProductionReadiness(
          enforceProductionReadiness: false,
          isProduction: true,
          readinessIssues: const <String>['Missing required setup.'],
        ),
        isFalse,
      );
      expect(
        Env.resolveShouldBlockStartupForProductionReadiness(
          enforceProductionReadiness: true,
          isProduction: false,
          readinessIssues: const <String>['Missing required setup.'],
        ),
        isFalse,
      );
      expect(
        Env.resolveShouldBlockStartupForProductionReadiness(
          enforceProductionReadiness: true,
          isProduction: true,
          readinessIssues: const <String>[],
        ),
        isFalse,
      );
    });

    testWidgets('blocked app exposes only a user-safe non-routable screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AppRoot(
            productionReadinessBlocked: true,
            startupError:
                'Production readiness configuration is incomplete: Supabase authentication is not configured.',
          ),
        ),
      );

      expect(find.text('ChronoSpark cannot start safely'), findsOneWidget);
      expect(find.textContaining('the app will remain closed'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Navigator), findsOneWidget);
      expect(find.textContaining('Supabase'), findsNothing);
      expect(find.textContaining('Production readiness'), findsNothing);
    });
  });
}
