import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IdentityAccountStatus {
  const IdentityAccountStatus({
    required this.hasIdentity,
    required this.displayName,
    required this.accountLabel,
    required this.syncLabel,
    required this.emailLabel,
  });

  final bool hasIdentity;
  final String displayName;
  final String accountLabel;
  final String syncLabel;
  final String emailLabel;
}

class IdentityAccountController extends Notifier<ChronoSparkIdentity?> {
  @override
  ChronoSparkIdentity? build() => null;

  void setIdentity(ChronoSparkIdentity identity) {
    state = identity.copyWith(lastActiveAt: DateTime.now());
  }

  void clear() {
    state = null;
  }

  void markEmailVerified() {
    final ChronoSparkIdentity? current = state;
    if (current == null) {
      return;
    }

    state = current.copyWith(
      emailVerified: true,
      syncStatus: ChronoSparkIdentitySyncStatus.synced,
      lastActiveAt: DateTime.now(),
    );
  }

  void updateLifeOsIdentity({
    required String mission,
    required String identityStage,
    required String futureVersionName,
  }) {
    final ChronoSparkIdentity? current = state;
    if (current == null) {
      return;
    }

    state = current.copyWith(
      lifeOsMission: mission,
      identityStage: identityStage,
      futureVersionName: futureVersionName,
      lastActiveAt: DateTime.now(),
    );
  }
}

final identityAccountProvider =
    NotifierProvider<IdentityAccountController, ChronoSparkIdentity?>(
      IdentityAccountController.new,
    );

final identityAccountStatusProvider = Provider<IdentityAccountStatus>((ref) {
  final ChronoSparkIdentity? identity = ref.watch(identityAccountProvider);

  if (identity == null) {
    return const IdentityAccountStatus(
      hasIdentity: false,
      displayName: 'Operator',
      accountLabel: 'Local Operator',
      syncLabel: 'Not linked',
      emailLabel: 'No account connected',
    );
  }

  return IdentityAccountStatus(
    hasIdentity: true,
    displayName: identity.displayLabel,
    accountLabel: identity.accountTier.name.toUpperCase(),
    syncLabel: identity.syncStatus.name,
    emailLabel: identity.emailVerified
        ? '${identity.email} verified'
        : '${identity.email} unverified',
  );
});
