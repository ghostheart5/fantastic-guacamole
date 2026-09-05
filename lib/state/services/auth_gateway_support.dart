import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/always_authenticated_auth_service.dart';
import 'package:fantastic_guacamole/data/services/auth_service.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/services/mock_auth_service.dart';
import 'package:fantastic_guacamole/data/services/local_profile_auth_service.dart';
import 'package:fantastic_guacamole/data/services/unavailable_auth_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

export 'package:fantastic_guacamole/data/models/auth_models.dart';
export 'package:fantastic_guacamole/data/services/local_profile_auth_service.dart';
export 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
export 'package:fantastic_guacamole/data/services/contracts/password_recovery_auth.dart';

AuthServiceContract createAuthService({
  required SecureStore store,
  required sb.SupabaseClient? supabaseClient,
  required IntelligenceState intelligence,
  LocalUserDataCleanupService? localDataCleanup,
  Future<void> Function(String accountId)? onBeforeSignedOut,
  Future<void> Function()? onDevicePushTokenRevoked,
  LocalProfileAuthService? localProfileService,
}) {
  if (intelligence.environment.isLocalMode) {
    return localProfileService ??
        const UnavailableAuthService(
          message:
              'Local profile storage is unavailable. Retry opening the app.',
        );
  }
  // Hard release guard. The flag cascade below is driven by env/flavor
  // resolution; this makes any misconfiguration of that resolution
  // non-exploitable in a shipped binary rather than merely unlikely. A release
  // build never gets a test identity or an any-password auth service.
  if (!kReleaseMode) {
    if (intelligence.flags.mockMode) {
      return AlwaysAuthenticatedAuthService(
        user: const User(
          id: 'mock-always-auth-user',
          email: 'mock@chronospark.app',
          displayName: 'Mock Planner',
          emailVerified: true,
        ),
        onBeforeSignedOut: onBeforeSignedOut,
        onAccountDeleted: localDataCleanup?.clearForAccountSwitch,
      );
    }
    if (intelligence.flags.mockLoginEnabled) {
      return MockAuthService(
        onBeforeSignedOut: onBeforeSignedOut,
        onAccountDeleted: localDataCleanup?.clearForAccountSwitch,
      );
    }
  }
  if (!intelligence.environment.isSupabaseConfigured) {
    return const UnavailableAuthService(
      message: 'Authentication backend is not configured for this build.',
    );
  }
  if (supabaseClient == null) {
    return const UnavailableAuthService(
      message:
          'Authentication backend has not finished initialization. Please retry.',
    );
  }
  return AuthService(
    supabaseClient: supabaseClient,
    store: store,
    onBeforeSignedOut: onBeforeSignedOut,
    onAccountDeleted: localDataCleanup?.clearForAccountSwitch,
    onDevicePushTokenRevoked: onDevicePushTokenRevoked,
  );
}
