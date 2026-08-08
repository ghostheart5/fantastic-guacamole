import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/always_authenticated_auth_service.dart';
import 'package:fantastic_guacamole/data/services/auth_service.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/services/mock_auth_service.dart';
import 'package:fantastic_guacamole/data/services/unavailable_auth_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

export 'package:fantastic_guacamole/data/models/auth_models.dart';
export 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';

AuthServiceContract createAuthService({
  required SecureStore store,
  required sb.SupabaseClient? supabaseClient,
  required IntelligenceState intelligence,
}) {
  // Hard release guard. The flag cascade below is driven by env/flavor
  // resolution; this makes any misconfiguration of that resolution
  // non-exploitable in a shipped binary rather than merely unlikely. A release
  // build never gets a credential-free or any-password auth service.
  if (!kReleaseMode) {
    if (intelligence.flags.mockMode) {
      return AlwaysAuthenticatedAuthService(
        user: const User(
          id: 'mock-always-auth-user',
          email: 'mock@chronospark.app',
          displayName: 'Mock Operator',
          emailVerified: true,
        ),
      );
    }
    if (intelligence.flags.mockLoginEnabled) {
      return MockAuthService();
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
  return AuthService(supabaseClient: supabaseClient, store: store);
}
