import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/features/auth/ui/account_deletion_status_panel.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('public deletion panel checks an opaque pending request', (
    WidgetTester tester,
  ) async {
    final _PendingDeletionAuthService service = _PendingDeletionAuthService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          home: Scaffold(body: AccountDeletionStatusPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account deletion status'), findsOneWidget);
    expect(
      find.text('Status: Sessions revoked; cleanup in progress'),
      findsOneWidget,
    );
    expect(find.text('Check status'), findsOneWidget);

    await tester.tap(find.text('Check status'));
    await tester.pumpAndSettle();

    expect(service.refreshCalls, 1);
    expect(
      find.text(
        'Account deletion completed. The status receipt was removed from this device.',
      ),
      findsOneWidget,
    );
  });
}

final class _PendingDeletionAuthService implements AuthServiceContract {
  int refreshCalls = 0;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(null);

  @override
  Future<PendingAccountDeletionStatus?> readPendingAccountDeletion() async {
    return PendingAccountDeletionStatus(
      serverState: 'sessions_revoked',
      createdAtUtc: DateTime.utc(2026, 9, 4),
      localCleanupCompleted: true,
    );
  }

  @override
  Future<AccountDeletionResult?> refreshPendingAccountDeletion() async {
    refreshCalls += 1;
    return const AccountDeletionResult.completed();
  }

  @override
  Future<void> forgetPendingAccountDeletion() async {}

  @override
  Future<AccountDeletionResult> deleteCurrentAccount({
    required String password,
  }) async => const AccountDeletionResult.completed();

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;

  @override
  Future<User?> reloadCurrentUser() async => null;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<UserCredential> signInWithGitHub() => throw UnimplementedError();

  @override
  Future<UserCredential> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> updatePassword({required String newPassword}) async {}
}
