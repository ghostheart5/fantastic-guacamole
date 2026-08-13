import 'package:fantastic_guacamole/data/models/auth_models.dart';
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

  ChronoSparkIdentity? synchronizeAuthenticatedUser(User? user) {
    if (user == null) {
      state = null;
      return null;
    }

    final DateTime now = DateTime.now();
    final String email = user.email?.trim() ?? '';
    final String displayName = user.displayName?.trim() ?? '';
    final ChronoSparkIdentity? current = state;
    final bool sameAccount =
        current != null &&
        (current.id == user.id ||
            (email.isNotEmpty &&
                current.email.trim().toLowerCase() == email.toLowerCase()));

    final ChronoSparkIdentity identity = ChronoSparkIdentity(
      id: user.id,
      email: email,
      displayName: displayName.isNotEmpty
          ? displayName
          : (email.isNotEmpty ? email : 'Operator'),
      photoUrl: sameAccount ? current.photoUrl : null,
      futureVersionName: sameAccount ? current.futureVersionName : null,
      lifeOsMission: sameAccount ? current.lifeOsMission : null,
      identityStage: sameAccount ? current.identityStage : null,
      accountTier: sameAccount ? current.accountTier : ChronoSparkAccountTier.free,
      authProvider: _resolveAuthProvider(user),
      syncStatus: ChronoSparkIdentitySyncStatus.synced,
      emailVerified: user.emailVerified,
      createdAt: sameAccount ? current.createdAt : now,
      lastActiveAt: now,
    );
    state = identity;
    return identity;
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

ChronoSparkAuthProvider _resolveAuthProvider(User user) {
  final Iterable<String> candidates = <String>[
    user.authenticationProvider ?? '',
    ...user.authenticationProviders,
  ];
  for (final String candidate in candidates) {
    switch (candidate.trim().toLowerCase()) {
      case 'google':
        return ChronoSparkAuthProvider.google;
      case 'github':
        return ChronoSparkAuthProvider.github;
      case 'apple':
        return ChronoSparkAuthProvider.apple;
      case 'azure':
      case 'microsoft':
        return ChronoSparkAuthProvider.microsoft;
      case 'anonymous':
        return ChronoSparkAuthProvider.anonymous;
      case 'email':
        return ChronoSparkAuthProvider.email;
    }
  }
  return user.id.startsWith('mock-')
      ? ChronoSparkAuthProvider.anonymous
      : ChronoSparkAuthProvider.email;
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
