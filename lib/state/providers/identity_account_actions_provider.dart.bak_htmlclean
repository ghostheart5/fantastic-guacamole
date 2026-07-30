import 'package:fantastic_guacamole/features/auth/data/repositories/local_identity_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IdentityAccountActionsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> initializeLocalIdentity({
    required String displayName,
    String email = '',
  }) async {
    state = const AsyncLoading<void>();

    state = await AsyncValue.guard(() async {
      final DateTime now = DateTime.now();

      final ChronoSparkIdentity identity = ChronoSparkIdentity(
        id: 'local-${now.millisecondsSinceEpoch}',
        email: email.trim(),
        displayName: displayName.trim().isEmpty
            ? 'Operator'
            : displayName.trim(),
        createdAt: now,
        lastActiveAt: now,
        accountTier: ChronoSparkAccountTier.free,
        authProvider: ChronoSparkAuthProvider.anonymous,
        syncStatus: ChronoSparkIdentitySyncStatus.localOnly,
        emailVerified: false,
      );

      final LocalIdentityRepository repository = LocalIdentityRepository();

      await repository.saveIdentity(identity);

      ref.read(identityAccountProvider.notifier).setIdentity(identity);
    });
  }

  Future<void> restoreLocalIdentity() async {
    state = const AsyncLoading<void>();

    state = await AsyncValue.guard(() async {
      final LocalIdentityRepository repository = LocalIdentityRepository();

      final ChronoSparkIdentity? identity = await repository.loadIdentity();

      if (identity == null) {
        return;
      }

      ref.read(identityAccountProvider.notifier).setIdentity(identity);
    });
  }

  Future<void> signOutLocalIdentity() async {
    state = const AsyncLoading<void>();

    state = await AsyncValue.guard(() async {
      final LocalIdentityRepository repository = LocalIdentityRepository();

      await repository.clearIdentity();

      ref.read(identityAccountProvider.notifier).clear();
    });
  }
}

final identityAccountActionsProvider =
    AsyncNotifierProvider<IdentityAccountActionsController, void>(
      IdentityAccountActionsController.new,
    );
