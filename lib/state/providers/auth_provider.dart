import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/services/supabase_client_service.dart';
import 'package:fantastic_guacamole/data/services/unavailable_auth_service.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthServiceContract>(
  (ref) => createAuthService(
    store: ref.read(secureStoreProvider),
    supabaseClient: ref.read(supabaseClientProvider),
    intelligence: ref.read(intelligenceStateProvider),
    localDataCleanup: ref.read(localUserDataCleanupServiceProvider),
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
