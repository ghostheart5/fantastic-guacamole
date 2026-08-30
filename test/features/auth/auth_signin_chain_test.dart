import 'dart:async';

import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real sign-in chain — credentials to signIn to an auth-state emission to
/// the app rendering — had no coverage. Only the mock-login shortcut was
/// tested, which bypasses the auth service entirely, so a regression in the
/// gate's response to a genuine sign-in would not have been caught.
///
/// These drive the contract rather than a backend, so nothing here touches
/// Firebase or Supabase configuration.
void main() {
  testWidgets('failed backend initialization has a working retry action', (
    WidgetTester tester,
  ) async {
    final _FakeAuthService service = _FakeAuthService();
    addTearDown(service.dispose);
    int backendAttempts = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(service),
          intelligenceStateProvider.overrideWithValue(
            _configuredIntelligenceState,
          ),
        ],
        child: MaterialApp(
          home: AuthGate(
            initializeBackend: () async {
              backendAttempts += 1;
              return backendAttempts <= 3
                  ? 'Sign-in services are temporarily unavailable.'
                  : null;
            },
            child: const Scaffold(body: Text('APP_READY')),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Sign-in services unavailable'), findsOneWidget);
    expect(find.text('Retry sign-in services'), findsOneWidget);
    expect(backendAttempts, 3);

    await tester.tap(find.text('Retry sign-in services'));
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(backendAttempts, 4);
    expect(find.text('ENTER SYSTEM'), findsOneWidget);
  });

  Future<void> pumpGate(
    WidgetTester tester,
    AuthServiceContract service,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AuthGate(
            authService: service,
            child: const Scaffold(body: Text('APP_READY')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> enterLoginCredentials(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    final Finder emailField = find.descendant(
      of: find.byKey(const ValueKey('login-email-field')),
      matching: find.byType(TextField),
    );
    final Finder passwordField = find.descendant(
      of: find.byKey(const ValueKey('login-password-field')),
      matching: find.byType(TextField),
    );
    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, password);
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(find.text('ENTER SYSTEM'));
    await tester.pump();
    await tester.tap(find.text('ENTER SYSTEM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('a signed-out user is held at the login surface', (
    WidgetTester tester,
  ) async {
    final _FakeAuthService service = _FakeAuthService();
    addTearDown(service.dispose);

    await pumpGate(tester, service);

    expect(find.text('APP_READY'), findsNothing);
    expect(find.text('ENTER SYSTEM'), findsOneWidget);
    expect(find.textContaining('TESTER ACCESS'), findsNothing);
  });

  testWidgets('a successful sign-in admits the user to the app', (
    WidgetTester tester,
  ) async {
    final _FakeAuthService service = _FakeAuthService();
    addTearDown(service.dispose);

    await pumpGate(tester, service);
    expect(find.text('APP_READY'), findsNothing);

    // The gate renders from the auth-state stream, not from the return value
    // of signIn, so the emission is what actually admits the user.
    await service.signIn(email: 'user@chronospark.app', password: 'Correct1!');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.signInCalls, 1);
    expect(find.text('APP_READY'), findsOneWidget);
  });

  testWidgets('a rejected sign-in leaves the user signed out', (
    WidgetTester tester,
  ) async {
    final _FakeAuthService service = _FakeAuthService(
      failWith: 'wrong-password',
    );
    addTearDown(service.dispose);

    await pumpGate(tester, service);

    await expectLater(
      service.signIn(email: 'user@chronospark.app', password: 'nope'),
      throwsA(isA<FirebaseAuthException>()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('APP_READY'),
      findsNothing,
      reason: 'A failed sign-in must never admit the user.',
    );
  });

  testWidgets('signing out returns the user to the login surface', (
    WidgetTester tester,
  ) async {
    final _FakeAuthService service = _FakeAuthService();
    addTearDown(service.dispose);

    await pumpGate(tester, service);
    await service.signIn(email: 'user@chronospark.app', password: 'Correct1!');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('APP_READY'), findsOneWidget);

    await service.signOut();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('APP_READY'),
      findsNothing,
      reason: 'Session teardown must revoke access to the app surface.',
    );
  });

  // L-27: the auth-state StreamBuilder's error branch was implemented but
  // untested — a backend hiccup on the stream itself must fail closed rather
  // than admit the user or crash the widget tree.
  testWidgets('an auth-state stream error is shown, not the app surface', (
    WidgetTester tester,
  ) async {
    final _FakeAuthService service = _FakeAuthService();
    addTearDown(service.dispose);

    await pumpGate(tester, service);
    expect(find.text('APP_READY'), findsNothing);

    service.emitStreamError('network-request-failed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('APP_READY'), findsNothing);
    expect(find.text('Authentication unavailable'), findsOneWidget);
  });

  testWidgets('toggling sign-up mode swaps the primary action and title', (
    WidgetTester tester,
  ) async {
    // Sign-up mode is only reachable when mock login is disabled — allowSignUp
    // is wired to !enableMockLogin (auth_gate.dart:435).
    //
    // The login form sits in a SingleChildScrollView and the toggle link is
    // below the fold at the default 800x600 test viewport; ensureVisible()
    // doesn't bring it fully into view there (same landmine worked around in
    // nexus_navigation_test.dart), so use a tall surface instead so the whole
    // form renders without needing to scroll.
    tester.platformDispatcher.views.first
      ..physicalSize = const Size(800, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final _FakeAuthService service = _FakeAuthService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AuthGate(
            authService: service,
            enableMockLogin: false,
            child: const Scaffold(body: Text('APP_READY')),
          ),
        ),
      ),
    );
    await tester.pump();
    // The form's 720ms entrance animation slides it up from below; settle it
    // fully before locating "Create Account". Pump in small increments so the
    // SlideTransition's paint/hit-test transform converges frame-by-frame
    // rather than jumping straight to the end value in one large tick.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('ENTER SYSTEM'), findsOneWidget);
    expect(find.text('ACCESS SYSTEM'), findsOneWidget);

    await tester.tap(find.text('Create Account'));
    await tester.pump();

    expect(find.text('INITIALIZE PROFILE'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);

    await tester.tap(find.text('Switch to Login'));
    await tester.pump();

    expect(find.text('ENTER SYSTEM'), findsOneWidget);
    expect(find.text('ACCESS SYSTEM'), findsOneWidget);
  });

  testWidgets('forgot password sends a reset for a valid email', (
    WidgetTester tester,
  ) async {
    final _FakeAuthService service = _FakeAuthService();
    addTearDown(service.dispose);

    await pumpGate(tester, service);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'user@chronospark.app',
    );
    await tester.tap(find.text('Forgot Password?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.passwordResetCalls, <String>['user@chronospark.app']);
    expect(find.text('Password reset link sent.'), findsOneWidget);
  });

  testWidgets(
    'forgot password rejects an invalid email without a network call',
    (WidgetTester tester) async {
      final _FakeAuthService service = _FakeAuthService();
      addTearDown(service.dispose);

      await pumpGate(tester, service);

      await tester.enterText(
        find.byKey(const ValueKey('login-email-field')),
        'not-an-email',
      );
      await tester.tap(find.text('Forgot Password?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(service.passwordResetCalls, isEmpty);
      expect(
        find.text('Enter account email, then trigger password reset.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'QA tester access opens a local test profile without credentials',
    (WidgetTester tester) async {
      tester.platformDispatcher.views.first
        ..physicalSize = const Size(800, 1400)
        ..devicePixelRatio = 1.0;
      addTearDown(() {
        tester.platformDispatcher.views.first
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });

      final _FakeAuthService service = _FakeAuthService(
        failWith: 'network-request-failed',
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AuthGate(
              authService: service,
              enableMockLogin: true,
              child: const Scaffold(body: Text('APP_READY')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Mock login:'), findsNothing);
      expect(
        find.text('QA tester build uses an isolated local test profile.'),
        findsOneWidget,
      );
      final Finder testerAccess = find.byKey(
        const ValueKey<String>('qa-tester-access-button'),
      );
      tester.widget<SmartPressable>(testerAccess).onTap();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(service.signInCalls, 0);
      expect(find.text('APP_READY'), findsOneWidget);
    },
  );

  testWidgets('email submission in QA never bypasses the auth service', (
    WidgetTester tester,
  ) async {
    final _FakeAuthService service = _FakeAuthService(
      failWith: 'wrong-password',
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AuthGate(
            authService: service,
            enableMockLogin: true,
            child: const Scaffold(body: Text('APP_READY')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await enterLoginCredentials(
      tester,
      email: 'qa-tester@chronospark.app',
      password: 'ordinary-password',
    );

    expect(service.signInCalls, 1);
    expect(find.text('APP_READY'), findsNothing);
  });

  testWidgets(
    'Google/GitHub sign-in buttons are hidden behind the mock-login hint',
    (WidgetTester tester) async {
      final _FakeAuthService service = _FakeAuthService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AuthGate(
              authService: service,
              enableMockLogin: true,
              child: const Scaffold(body: Text('APP_READY')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with GitHub'), findsNothing);
      expect(find.textContaining('TESTER ACCESS'), findsOneWidget);
    },
  );

  testWidgets(
    'Google/GitHub sign-in buttons render once mock login is disabled',
    (WidgetTester tester) async {
      final _FakeAuthService service = _FakeAuthService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AuthGate(
              authService: service,
              enableMockLogin: false,
              child: const Scaffold(body: Text('APP_READY')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with GitHub'), findsOneWidget);
    },
  );
}

const IntelligenceState _configuredIntelligenceState = IntelligenceState(
  environment: EnvironmentState(
    appName: 'ChronoSpark',
    appFlavor: 'test',
    isProduction: false,
    isSupabaseConfigured: true,
  ),
  flags: FeatureFlagsState(
    verboseLogs: false,
    analyticsEnabled: false,
    mockMode: false,
    mockLoginEnabled: false,
    paywallDisabled: true,
    testerFullAccess: false,
  ),
  auth: AuthStateSnapshot(hasMockSignIn: false, hasAuthenticatedUser: false),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);

/// Drives the auth-state stream the way a real backend would: sign-in and
/// sign-out push emissions rather than the gate polling for a user.
class _FakeAuthService implements AuthServiceContract {
  _FakeAuthService({this.failWith});

  final String? failWith;
  final StreamController<User?> _authState =
      StreamController<User?>.broadcast();

  User? _current;
  int signInCalls = 0;
  final List<String> passwordResetCalls = <String>[];

  void dispose() => unawaited(_authState.close());

  void emitStreamError(Object error) => _authState.addError(error);

  @override
  Stream<User?> authStateChanges() async* {
    yield _current;
    yield* _authState.stream;
  }

  @override
  User? get currentUser => _current;

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    final String? code = failWith;
    if (code != null) {
      throw FirebaseAuthException(code: code);
    }
    _current = User(id: 'user-1', email: email, emailVerified: true);
    _authState.add(_current);
    return UserCredential(user: _current);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _authState.add(null);
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) => signIn(email: email, password: password);

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      _current == null ? null : 'token';

  @override
  Future<void> deleteCurrentAccount({required String password}) async {
    await signOut();
  }

  @override
  Future<User?> reloadCurrentUser() async => _current;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {
    passwordResetCalls.add(email);
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {}

  @override
  Future<UserCredential> signInWithGoogle() =>
      throw UnimplementedError('Not exercised by the credential chain');

  @override
  Future<UserCredential> signInWithGitHub() =>
      throw UnimplementedError('Not exercised by the credential chain');
}
