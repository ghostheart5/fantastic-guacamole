import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auth screen exposes forgot password action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authService: _IntegrationFakeAuthService(),
          child: const Text('APP_READY'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forgot password?'), findsOneWidget);
  });
}

class _IntegrationFakeAuthService implements AuthServiceContract {
  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(null);

  @override
  User? get currentUser => null;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;

  @override
  Future<void> deleteCurrentAccount({required String password}) async {}

  @override
  Future<User?> reloadCurrentUser() async => null;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<UserCredential> signInWithGoogle() {
    throw UnimplementedError('Not used by this integration test');
  }

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    throw UnimplementedError('Not used by this integration test');
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    throw UnimplementedError('Not used by this integration test');
  }
}
