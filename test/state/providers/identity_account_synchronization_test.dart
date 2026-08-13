import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same account retains only authorized optional identity state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final IdentityAccountController controller = container.read(identityAccountProvider.notifier);
    final DateTime createdAt = DateTime.utc(2026, 1, 1);
    controller.setIdentity(ChronoSparkIdentity(
      id: 'user-a', email: 'a@example.com', displayName: 'A',
      photoUrl: 'https://photo/a', futureVersionName: 'Future A',
      lifeOsMission: 'Mission A', identityStage: 'Builder',
      accountTier: ChronoSparkAccountTier.pro, createdAt: createdAt, lastActiveAt: createdAt,
    ));

    final ChronoSparkIdentity? value = controller.synchronizeAuthenticatedUser(const User(
      id: 'user-a', email: ' A@EXAMPLE.COM ', displayName: 'Current A',
      emailVerified: true, authenticationProvider: 'google',
    ));
    expect(value, isNotNull);
    expect(value!.displayName, 'Current A');
    expect(value.photoUrl, 'https://photo/a');
    expect(value.futureVersionName, 'Future A');
    expect(value.lifeOsMission, 'Mission A');
    expect(value.identityStage, 'Builder');
    expect(value.accountTier, ChronoSparkAccountTier.pro);
    expect(value.createdAt, createdAt);
    expect(value.authProvider, ChronoSparkAuthProvider.google);
  });

  test('different user and signed-out user cannot retain A state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final IdentityAccountController controller = container.read(identityAccountProvider.notifier);
    controller.setIdentity(ChronoSparkIdentity(
      id: 'user-a', email: 'a@example.com', displayName: 'A', photoUrl: 'a-photo',
      futureVersionName: 'A future', lifeOsMission: 'A mission', identityStage: 'A stage',
      accountTier: ChronoSparkAccountTier.founder,
      createdAt: DateTime.utc(2026, 1, 1), lastActiveAt: DateTime.utc(2026, 1, 1),
    ));

    final ChronoSparkIdentity? userB = controller.synchronizeAuthenticatedUser(const User(
      id: 'user-b', email: 'b@example.com', emailVerified: false,
    ));
    expect(userB!.id, 'user-b');
    expect(userB.photoUrl, isNull);
    expect(userB.futureVersionName, isNull);
    expect(userB.lifeOsMission, isNull);
    expect(userB.identityStage, isNull);
    expect(userB.accountTier, ChronoSparkAccountTier.free);
    expect(controller.synchronizeAuthenticatedUser(null), isNull);
    expect(container.read(identityAccountProvider), isNull);
    expect(controller.synchronizeAuthenticatedUser(null), isNull);
  });
}
