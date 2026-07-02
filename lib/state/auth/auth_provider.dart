import 'package:fantastic_guacamole/data/di/services_providers.dart';
import 'package:fantastic_guacamole/state/auth/auth_gateway_support.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthServiceContract>(
  (ref) => createAuthService(
    store: ref.read(secureStoreProvider),
    supabaseClient: ref.read(supabaseClientProvider),
    intelligence: ref.read(intelligenceStateProvider),
  ),
);
