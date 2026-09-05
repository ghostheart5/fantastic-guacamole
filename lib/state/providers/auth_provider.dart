import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/state/providers/local_profile_auth_provider.dart';
import 'package:fantastic_guacamole/data/services/supabase_client_service.dart';
import 'package:fantastic_guacamole/data/services/unavailable_auth_service.dart';
import 'package:fantastic_guacamole/data/services/supabase_password_recovery.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_messaging_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final passwordRecoveryStateProvider = StreamProvider<PasswordRecoveryState>((
  ref,
) {
  if (!Env.cloudServicesEnabled) {
    return Stream<PasswordRecoveryState>.value(
      const PasswordRecoveryState.inactive(),
    );
  }
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return Stream<PasswordRecoveryState>.value(
      const PasswordRecoveryState.inactive(),
    );
  }
  return SupabasePasswordRecovery.forClient(client).changes;
});

final authServiceProvider = Provider<AuthServiceContract>(
  (ref) => createAuthService(
    store: ref.read(secureStoreProvider),
    supabaseClient: Env.cloudServicesEnabled
        ? ref.read(supabaseClientProvider)
        : null,
    intelligence: ref.read(intelligenceStateProvider),
    localProfileService: Env.isLocalMode
        ? ref.read(localProfileAuthServiceProvider)
        : null,
    localDataCleanup: ref.read(localUserDataCleanupServiceProvider),
    onBeforeSignedOut: ref
        .read(localUserDataCleanupServiceProvider)
        .cancelScheduledNotificationsForAccount,
    onDevicePushTokenRevoked:
        const FirebaseMessagingBootstrap().revokeDeviceToken,
  ),
);

/// Owns the concrete runtime dependencies needed while the authentication
/// gate is starting. UI code consumes this boundary without constructing or
/// identifying backend implementations itself.
class AuthRuntimeCoordinator {
  AuthRuntimeCoordinator(this._ref);

  final Ref _ref;

  AuthServiceContract get unavailableService => const UnavailableAuthService();

  Future<String?> initializeBackend({required bool isMockMode}) {
    if (Env.isLocalMode) return Future<String?>.value();
    return const SupabaseClientService().initialize(isMockMode: isMockMode);
  }

  AuthServiceContract readService() => _ref.read(authServiceProvider);

  bool isUnavailable(AuthServiceContract service) {
    return service is UnavailableAuthService;
  }

  void refreshService() {
    _ref.invalidate(supabaseClientProvider);
    _ref.invalidate(authServiceProvider);
  }
}

final authRuntimeCoordinatorProvider = Provider<AuthRuntimeCoordinator>((
  Ref ref,
) {
  return AuthRuntimeCoordinator(ref);
});
