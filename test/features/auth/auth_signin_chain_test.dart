import 'dart:async';

import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
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
  Future<void> pumpGate(WidgetTester tester, AuthServiceContract service) async {
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

  testWidgets('a signed-out user is held at the login surface', (
    WidgetTester tester,
  ) async {
    final _FakeAuthService service = _FakeAuthService();
    addTearDown(service.dispose);

    await pumpGate(tester, service);

    expect(find.text('APP_READY'), findsNothing);
    expect(find.text('ENTER SYSTEM'), findsOneWidget);
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
    final _FakeAuthService service = _FakeAuthService(failWith: 'wrong-password');
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
}

/// Drives the auth-state stream the way a real backend would: sign-in and
/// sign-out push emissions rather than the gate polling for a user.
class _FakeAuthService implements AuthServiceContract {
  _FakeAuthService({this.failWith});

  final String? failWith;
  final StreamController<User?> _authState =
      StreamController<User?>.broadcast();

  User? _current;
  int signInCalls = 0;

  void dispose() => unawaited(_authState.close());

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
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword({required String newPassword}) async {}

  @override
  Future<UserCredential> signInWithGoogle() =>
      throw UnimplementedError('Not exercised by the credential chain');

  @override
  Future<UserCredential> signInWithGitHub() =>
      throw UnimplementedError('Not exercised by the credential chain');
}
