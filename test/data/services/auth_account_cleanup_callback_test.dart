import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/always_authenticated_auth_service.dart';
import 'package:fantastic_guacamole/data/services/mock_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock sign-out identifies the departing account to cleanup', () async {
    String? cleanedAccountId;
    final MockAuthService service = MockAuthService(
      onAccountSignedOut: (String? accountId) async {
        cleanedAccountId = accountId;
      },
    );
    await service.signIn(email: 'test@example.com', password: 'password');

    await service.signOut();

    expect(cleanedAccountId, 'mock-user');
  });

  test('always-authenticated cleanup receives its fixed owner', () async {
    String? cleanedAccountId;
    final AlwaysAuthenticatedAuthService service =
        AlwaysAuthenticatedAuthService(
          user: const User(id: 'always-user', emailVerified: true),
          onAccountSignedOut: (String? accountId) async {
            cleanedAccountId = accountId;
          },
        );

    await service.signOut();

    expect(cleanedAccountId, 'always-user');
  });
}
