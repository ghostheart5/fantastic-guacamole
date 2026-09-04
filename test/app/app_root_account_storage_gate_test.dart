import 'dart:async';

import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'authenticated UI stays locked until account storage is writable',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            intelligenceStateProvider.overrideWithValue(
              _authenticatedIntelligence,
            ),
            authSessionBoundaryProvider.overrideWith(_ReadyBoundary.new),
            accountStorageScopeProvider.overrideWithValue(
              const AccountStorageScope.unsafe(),
            ),
          ],
          child: const AppRoot(),
        ),
      );
      await tester.pump();

      expect(find.text('Securing account data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('blocked boundary exposes and serializes every recovery path', (
    WidgetTester tester,
  ) async {
    final Completer<void> claim = Completer<void>();
    await _pumpBlockedLock(
      tester,
      boundary: const AuthSessionBoundary(
        generation: 2,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: false,
        blockingIssue: 'internal detail',
        canRecoverBySigningOut: true,
        canClaimPreservedData: true,
        canClearPreservedData: true,
      ),
      actions: AccountDataLockActions(
        claimPreservedData: () => claim.future,
        clearPreservedData: () async {},
        signOut: () async {},
      ),
    );

    expect(find.byKey(const Key('account-lock-claim')), findsOneWidget);
    expect(find.byKey(const Key('account-lock-clear')), findsOneWidget);
    expect(find.byKey(const Key('account-lock-sign-out')), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-lock-claim')));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('account-lock-claim')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('account-lock-sign-out')),
          )
          .onPressed,
      isNull,
    );

    claim.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('account-lock-claim')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('failed recovery stays retryable and hides the raw error', (
    WidgetTester tester,
  ) async {
    await _pumpBlockedLock(
      tester,
      boundary: const AuthSessionBoundary(
        generation: 3,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: false,
        blockingIssue: 'private storage exception',
        canRecoverBySigningOut: true,
      ),
      actions: AccountDataLockActions(
        claimPreservedData: () async {},
        clearPreservedData: () async {},
        signOut: () =>
            Future<void>.error(StateError('private storage exception')),
      ),
    );

    await tester.tap(find.byKey(const Key('account-lock-sign-out')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('account-lock-operation-error')),
      findsOneWidget,
    );
    expect(find.textContaining('recovery action could not'), findsOneWidget);
    expect(find.textContaining('private storage exception'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('account-lock-sign-out')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('sign-out recovery is localized in Spanish', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('es'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    await _pumpBlockedLock(
      tester,
      boundary: const AuthSessionBoundary(
        generation: 4,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: false,
        blockingIssue: 'internal detail',
        canRecoverBySigningOut: true,
      ),
      actions: AccountDataLockActions(
        claimPreservedData: () async {},
        clearPreservedData: () async {},
        signOut: () async {},
      ),
    );

    expect(find.text('Cerrar sesión y volver al inicio'), findsOneWidget);
    expect(find.textContaining('internal detail'), findsNothing);
  });
}

Future<void> _pumpBlockedLock(
  WidgetTester tester, {
  required AuthSessionBoundary boundary,
  required AccountDataLockActions actions,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        intelligenceStateProvider.overrideWithValue(_authenticatedIntelligence),
        authSessionBoundaryProvider.overrideWith(
          () => _FixedBoundary(boundary),
        ),
        accountStorageScopeProvider.overrideWithValue(
          const AccountStorageScope.unsafe(),
        ),
        accountDataLockActionsProvider.overrideWithValue(actions),
      ],
      child: const AppRoot(),
    ),
  );
  await tester.pump();
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

class _FixedBoundary extends AuthSessionBoundaryNotifier {
  _FixedBoundary(this.boundary);

  final AuthSessionBoundary boundary;

  @override
  AuthSessionBoundary build() => boundary;
}

const IntelligenceState _authenticatedIntelligence = IntelligenceState(
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
