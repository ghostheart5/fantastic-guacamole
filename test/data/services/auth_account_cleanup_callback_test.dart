import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/always_authenticated_auth_service.dart';
import 'package:fantastic_guacamole/data/services/mock_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock sign-out preserves local account data', () async {
    int cleanupCalls = 0;
    final MockAuthService service = MockAuthService(
      onAccountDeleted: (String accountId) async {
        cleanupCalls += 1;
      },
    );
    await service.signIn(email: 'test@example.com', password: 'password');

    await service.signOut();

    expect(cleanupCalls, 0);
  });

  test('mock deletion cleans its original owner exactly once', () async {
    int cleanupCalls = 0;
    String? cleanedAccountId;
    final MockAuthService service = MockAuthService(
      onAccountDeleted: (String accountId) async {
        cleanupCalls += 1;
        cleanedAccountId = accountId;
      },
    );
    await service.signIn(email: 'test@example.com', password: 'password');

    await service.deleteCurrentAccount(password: 'password');

    expect(cleanupCalls, 1);
    expect(cleanedAccountId, 'mock-user');
  });

  test('mock unauthenticated deletion does not request cleanup', () async {
    int cleanupCalls = 0;
    final MockAuthService service = MockAuthService(
      onAccountDeleted: (String accountId) async {
        cleanupCalls += 1;
      },
    );

    await expectLater(
      service.deleteCurrentAccount(password: 'password'),
      throwsA(
        isA<FirebaseAuthException>().having(
          (FirebaseAuthException error) => error.code,
          'code',
          'no-current-user',
        ),
      ),
    );

    expect(cleanupCalls, 0);
  });

  test('always-authenticated sign-out preserves local account data', () async {
    int cleanupCalls = 0;
    final AlwaysAuthenticatedAuthService service =
        AlwaysAuthenticatedAuthService(
          user: const User(id: 'always-user', emailVerified: true),
          onAccountDeleted: (String accountId) async {
            cleanupCalls += 1;
          },
        );

    await service.signOut();

    expect(cleanupCalls, 0);
  });

  test('always-authenticated deletion cleans its owner exactly once', () async {
    int cleanupCalls = 0;
    String? cleanedAccountId;
    final AlwaysAuthenticatedAuthService service =
        AlwaysAuthenticatedAuthService(
          user: const User(id: 'always-user', emailVerified: true),
          onAccountDeleted: (String accountId) async {
            cleanupCalls += 1;
            cleanedAccountId = accountId;
          },
        );

    await service.deleteCurrentAccount(password: 'password');

    expect(cleanupCalls, 1);
    expect(cleanedAccountId, 'always-user');
  });
}
