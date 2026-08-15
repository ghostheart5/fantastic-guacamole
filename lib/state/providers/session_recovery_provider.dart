import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/services/session_recovery_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionRecoveryProvider = Provider<SessionRecoveryService>((Ref ref) {
  return SessionRecoveryService(
    storageScope: ref.watch(accountStorageScopeProvider),
  );
});
