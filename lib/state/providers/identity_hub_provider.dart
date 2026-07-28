import 'package:fantastic_guacamole/state/providers/account_connection_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_security_provider.dart';
import 'package:fantastic_guacamole/state/providers/chronospark_passport_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IdentityHubState {
  const IdentityHubState({
    required this.operatorName,
    required this.passportId,
    required this.identityStage,
    required this.securityLevel,
    required this.connectionCount,
    required this.syncReady,
  });

  final String operatorName;
  final String passportId;
  final String identityStage;
  final String securityLevel;
  final int connectionCount;
  final bool syncReady;
}

final identityHubProvider = Provider<IdentityHubState>((ref) {
  final passport = ref.watch(chronoSparkPassportProvider);

  final security = ref.watch(accountSecurityProvider);

  final connections = ref.watch(accountConnectionProvider);

  final sync = ref.watch(identitySyncProvider);

  final int connectedCount = connections.connections
      .where((c) => c.status == AccountConnectionStatus.connected)
      .length;

  return IdentityHubState(
    operatorName: passport.operatorName,
    passportId: passport.passportId,
    identityStage: passport.identityStage,
    securityLevel: security.level.name.toUpperCase(),
    connectionCount: connectedCount,
    syncReady: sync.ready,
  );
});
