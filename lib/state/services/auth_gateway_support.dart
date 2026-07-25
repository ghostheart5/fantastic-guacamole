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
import 'package:fantastic_guacamole/config/env.dart';
export 'package:fantastic_guacamole/data/models/auth_models.dart';
export 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';

AuthServiceContract createAuthService({
  required SecureStore store,
  required sb.SupabaseClient? supabaseClient,
  required IntelligenceState intelligence,
}) {
  final bool mockModeEnabled = intelligence.flags.mockMode || Env.isMockMode;

  final bool mockLoginEnabled =
      intelligence.flags.mockLoginEnabled ||
      Env.isMockLoginEnabled ||
      Env.hasTesterFullAccess;

  final bool supabaseConfigured =
      intelligence.environment.isSupabaseConfigured || Env.isSupabaseConfigured;

  debugPrint(
    'CHRONOSPARK_AUTH_GATEWAY: '
    'mockMode=$mockModeEnabled, '
    'mockLogin=$mockLoginEnabled, '
    'supabaseConfigured=$supabaseConfigured, '
    'supabaseClientReady=${supabaseClient != null}',
  );

  if (mockModeEnabled) {
    debugPrint(
      'CHRONOSPARK_AUTH_GATEWAY_SELECTED: AlwaysAuthenticatedAuthService',
    );

    return AlwaysAuthenticatedAuthService(
      user: const User(
        id: 'mock-always-auth-user',
        email: 'mock@chronospark.app',
        displayName: 'Mock Operator',
        emailVerified: true,
      ),
    );
  }

  if (mockLoginEnabled) {
    debugPrint('CHRONOSPARK_AUTH_GATEWAY_SELECTED: MockAuthService');
    return MockAuthService();
  }

  if (!supabaseConfigured) {
    debugPrint(
      'CHRONOSPARK_AUTH_GATEWAY_SELECTED: UnavailableAuthService not configured',
    );

    return const UnavailableAuthService(
      message: 'Authentication backend is not configured for this build.',
    );
  }

  if (supabaseClient == null) {
    debugPrint(
      'CHRONOSPARK_AUTH_GATEWAY_SELECTED: UnavailableAuthService backend not ready',
    );

    return const UnavailableAuthService(
      message:
          'Authentication backend has not finished initialization. Please retry.',
    );
  }

  debugPrint('CHRONOSPARK_AUTH_GATEWAY_SELECTED: AuthService');

  return AuthService(supabaseClient: supabaseClient, store: store);
}
