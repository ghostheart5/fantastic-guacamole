import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum IdentitySessionState { signedOut, localIdentity, accountIdentity }

class IdentitySessionBridgeState {
  const IdentitySessionBridgeState({
    required this.state,
    required this.displayName,
    required this.accountTier,
    required this.authProvider,
  });

  final IdentitySessionState state;
  final String displayName;
  final String accountTier;
  final String authProvider;
}

final identitySessionBridgeProvider = Provider<IdentitySessionBridgeState>((
  ref,
) {
  final ChronoSparkIdentity? identity = ref.watch(identityAccountProvider);

  if (identity == null) {
    return const IdentitySessionBridgeState(
      state: IdentitySessionState.signedOut,
      displayName: 'Guest',
      accountTier: 'NONE',
      authProvider: 'NONE',
    );
  }

  return IdentitySessionBridgeState(
    state: identity.syncStatus == ChronoSparkIdentitySyncStatus.localOnly
        ? IdentitySessionState.localIdentity
        : IdentitySessionState.accountIdentity,
    displayName: identity.displayLabel,
    accountTier: identity.accountTier.name.toUpperCase(),
    authProvider: identity.authProvider.name.toUpperCase(),
  );
});
