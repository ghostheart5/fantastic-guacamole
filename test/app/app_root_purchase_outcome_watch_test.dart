import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app root keeps the purchase-outcome watch alive for the whole run, so
/// a purchase finishing with the plans screen closed still forgets the Chat
/// balance it changed.
void main() {
  testWidgets('the app root watches purchase outcomes for the whole run', (
    WidgetTester tester,
  ) async {
    var builds = 0;
    var disposed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiCreditPurchaseOutcomeWatchProvider.overrideWith((ref) {
            builds++;
            ref.onDispose(() => disposed = true);
          }),
          intelligenceStateProvider.overrideWithValue(_intelligence),
          authSessionBoundaryProvider.overrideWith(_ReadyBoundary.new),
          accountStorageScopeProvider.overrideWithValue(
            const AccountStorageScope.unsafe(),
          ),
        ],
        child: const AppRoot(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(builds, 1);
    expect(disposed, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _ReadyBoundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'account-a',
    isTransitioning: false,
    isStorageReady: true,
  );
}

const IntelligenceState _intelligence = IntelligenceState(
  environment: EnvironmentState(
    appName: 'ChronoSpark',
    appFlavor: 'qa',
    isProduction: false,
    isSupabaseConfigured: false,
  ),
  flags: FeatureFlagsState(
    verboseLogs: false,
    analyticsEnabled: false,
    mockMode: true,
    mockLoginEnabled: true,
    paywallDisabled: true,
    testerFullAccess: true,
  ),
  auth: AuthStateSnapshot(hasMockSignIn: true, hasAuthenticatedUser: false),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);
