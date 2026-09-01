import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter/foundation.dart';
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

    test('evaluates Firebase readiness only after bootstrap is known', () {
      expect(
        Env.resolveShouldUseFirebaseFeatureFlags(
          isMockMode: false,
          enableRuntimeFeatureFlags: true,
          firebaseInitialized: true,
          firebaseProjectId: Env.expectedFirebaseProjectId,
        ),
        isTrue,
      );
      expect(
        Env.resolveShouldUseFirebaseFeatureFlags(
          isMockMode: false,
          enableRuntimeFeatureFlags: true,
          firebaseInitialized: false,
          firebaseProjectId: null,
        ),
        isFalse,
      );
      expect(
        Env.resolveFirebaseFeatureFlagReadinessIssue(
          isMockMode: false,
          enableRuntimeFeatureFlags: true,
          firebaseInitialized: null,
          firebaseProjectId: null,
        ),
        isNull,
      );
      expect(
        Env.resolveFirebaseFeatureFlagReadinessIssue(
          isMockMode: false,
          enableRuntimeFeatureFlags: true,
          firebaseInitialized: false,
          firebaseProjectId: null,
        ),
        contains('Firebase core'),
      );
      expect(
        Env.resolveFirebaseFeatureFlagReadinessIssue(
          isMockMode: false,
          enableRuntimeFeatureFlags: true,
          firebaseInitialized: true,
          firebaseProjectId: Env.expectedFirebaseProjectId,
        ),
        isNull,
      );
      expect(
        Env.resolveFirebaseFeatureFlagReadinessIssue(
          isMockMode: false,
          enableRuntimeFeatureFlags: true,
          firebaseInitialized: true,
          firebaseProjectId: 'another-firebase-project',
        ),
        contains('expected ChronoSpark Firebase project'),
      );
      expect(
        Env.resolveShouldUseFirebaseFeatureFlags(
          isMockMode: false,
          enableRuntimeFeatureFlags: true,
          firebaseInitialized: true,
          firebaseProjectId: 'another-firebase-project',
        ),
        isFalse,
      );
      expect(
        Env.resolveFirebaseFeatureFlagReadinessIssue(
          isMockMode: false,
          enableRuntimeFeatureFlags: false,
          firebaseInitialized: false,
          firebaseProjectId: null,
        ),
        isNull,
      );
      expect(
        Env.resolveFirebaseFeatureFlagReadinessIssue(
          isMockMode: true,
          enableRuntimeFeatureFlags: true,
          firebaseInitialized: false,
          firebaseProjectId: null,
        ),
        isNull,
      );
    });

    test('aggregates readiness issues from every config boundary', () {
      final List<String> issues = Env.productionReadinessIssues(
        force: true,
        firebaseInitialized: false,
        firebaseProjectId: null,
      );
      final String? firebaseIssue =
          Env.resolveFirebaseFeatureFlagReadinessIssue(
            isMockMode: Env.isMockMode,
            enableRuntimeFeatureFlags: Env.enableRuntimeFeatureFlags,
            firebaseInitialized: false,
            firebaseProjectId: null,
          );
      bool hasEndpointIssue(String label) =>
          issues.any((String issue) => issue.startsWith(label));
      bool endpointIsUnsafe(String value) =>
          value.trim().isEmpty || !Env.resolveIsValidHttpsEndpoint(value);

      expect(Env.enableCrashReporting, isFalse);
      expect(Env.enableAnalytics, isFalse);
      expect(
        issues.contains('Mock login bypass is enabled.'),
        Env.enableMockLogin,
      );
      expect(
        issues.contains('Global mock mode is enabled.'),
        Env.enableMockMode,
      );
      expect(
        issues.contains('Paywall-disabled development override is enabled.'),
        Env.enablePaywallDisabled,
      );
      expect(
        issues.contains('Tester full-access override is enabled.'),
        Env.enableTesterFullAccess,
      );
      expect(
        issues.contains('Supabase URL must be a valid root HTTPS URL.'),
        !Env.resolveIsValidSupabaseUrl(Env.supabaseUrl),
      );
      expect(
        issues.contains('Supabase publishable key is missing or malformed.'),
        !Env.resolveIsValidSupabaseAnonKey(Env.supabaseAnonKey),
      );
      expect(hasEndpointIssue('Receipt verification endpoint'), isFalse);
      expect(hasEndpointIssue('AI proxy endpoint'), isFalse);
      expect(hasEndpointIssue('AI report endpoint'), isFalse);
      expect(
        hasEndpointIssue('Account deletion endpoint'),
        endpointIsUnsafe(Env.accountDeleteEndpoint),
      );
      expect(
        issues.contains(
          'Android App Links SHA-256 fingerprint is not configured.',
        ),
        !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            Env.appLinksAndroidSha256.trim().isEmpty,
      );
      expect(
        issues.contains('iOS associated domains team ID is not configured.'),
        !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS) &&
            Env.appLinksIosTeamId.trim().isEmpty,
      );
      expect(
        issues.any(
          (String issue) =>
              issue.contains('Runtime feature flags require Firebase core'),
        ),
        firebaseIssue != null,
      );
      if (firebaseIssue != null) {
        expect(issues, contains(firebaseIssue));
      }
      expect(issues.toSet().length, issues.length);
    });

    test('requires mobile link identity only for the target platform', () {
      final List<String> androidIssues = Env.productionReadinessIssues(
        force: true,
        targetPlatform: TargetPlatform.android,
        isWeb: false,
      );
      final List<String> iosIssues = Env.productionReadinessIssues(
        force: true,
        targetPlatform: TargetPlatform.iOS,
        isWeb: false,
      );

      expect(
        androidIssues.contains(
          'Android App Links SHA-256 fingerprint is not configured.',
        ),
        Env.appLinksAndroidSha256.trim().isEmpty,
      );
      expect(
        androidIssues.contains(
          'iOS associated domains team ID is not configured.',
        ),
        isFalse,
      );
      expect(
        iosIssues.contains(
          'Android App Links SHA-256 fingerprint is not configured.',
        ),
        isFalse,
      );
      expect(
        iosIssues.contains('iOS associated domains team ID is not configured.'),
        Env.appLinksIosTeamId.trim().isEmpty,
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
