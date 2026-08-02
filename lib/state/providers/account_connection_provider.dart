import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AccountConnectionStatus { disconnected, connected, pending }

class AccountConnection {
  const AccountConnection({
    required this.provider,
    required this.status,
    required this.label,
  });

  final ChronoSparkAuthProvider provider;
  final AccountConnectionStatus status;
  final String label;
}

class AccountConnectionState {
  const AccountConnectionState({required this.connections});

  final List<AccountConnection> connections;
}

final accountConnectionProvider = Provider<AccountConnectionState>((ref) {
  final ChronoSparkIdentity? identity = ref.watch(identityAccountProvider);
  final bool hasIdentity = identity != null;
  final bool hasEmail = (identity?.email.trim().isNotEmpty ?? false);
  final bool supabaseConfigured = Env.isSupabaseConfigured;

  final AccountConnectionStatus emailStatus = hasIdentity && hasEmail
      ? AccountConnectionStatus.connected
      : AccountConnectionStatus.disconnected;

  // Google is marked connected only with an explicit provider signal.
  // If there is no reliable signal, keep it pending instead of asserting disconnected.
  final AccountConnectionStatus googleStatus = switch (identity?.authProvider) {
    ChronoSparkAuthProvider.google => AccountConnectionStatus.connected,
    _ =>
      supabaseConfigured
          ? AccountConnectionStatus.pending
          : AccountConnectionStatus.disconnected,
  };

  return AccountConnectionState(
    connections: <AccountConnection>[
      AccountConnection(
        provider: ChronoSparkAuthProvider.email,
        status: emailStatus,
        label: hasIdentity
            ? (hasEmail ? 'Primary Identity' : 'Identity missing email')
            : 'No identity available',
      ),
      AccountConnection(
        provider: ChronoSparkAuthProvider.google,
        status: googleStatus,
        label: googleStatus == AccountConnectionStatus.connected
            ? 'Google linked'
            : supabaseConfigured
            ? 'Google availability unknown'
            : 'Google unavailable (Supabase not configured)',
      ),
    ],
  );
});
