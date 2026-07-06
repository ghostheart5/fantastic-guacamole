import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:fantastic_guacamole/state/services/intelligence_service.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final mockAuthSessionProvider = NotifierProvider<MockAuthSessionNotifier, bool>(
  MockAuthSessionNotifier.new,
);

class MockAuthSessionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final authUserProvider = StreamProvider<User?>((ref) {
  final sb.SupabaseClient? client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return Stream<User?>.value(null);
  }

  final Stream<User?> authStateStream = client.auth.onAuthStateChange.map((
    event,
  ) {
    final sb.User? sbUser = event.session?.user ?? client.auth.currentUser;
    return _mapSupabaseUser(sbUser);
  });

  return (() async* {
    yield _mapSupabaseUser(client.auth.currentUser);
    yield* authStateStream;
  })();
});

final intelligenceServiceProvider = Provider<IntelligenceService>((ref) {
  return const IntelligenceService();
});

final mockLoginConfigProvider = Provider<MockLoginConfigState>((ref) {
  return ref.read(intelligenceServiceProvider).mockLoginConfig();
});

final intelligenceStateProvider = Provider<IntelligenceState>((ref) {
  // Exposes assistant/chat runtime intelligence to UI and controllers.
  final bool hasMockSession = ref.watch(mockAuthSessionProvider);
  final bool hasAuthenticatedUser = ref
      .watch(authUserProvider)
      .maybeWhen(data: (User? user) => user != null, orElse: () => false);

  return ref
      .read(intelligenceServiceProvider)
      .fromRuntime(
        hasMockSession: hasMockSession,
        hasAuthenticatedUser: hasAuthenticatedUser,
      );
});

final authenticatedGuardProvider = Provider<bool>((ref) {
  return ref.watch(intelligenceStateProvider).auth.isAuthenticated;
});

User? _mapSupabaseUser(sb.User? supabaseUser) {
  if (supabaseUser == null) {
    return null;
  }
  final Map<String, dynamic> metadata =
      supabaseUser.userMetadata ?? const <String, dynamic>{};
  final String? fullName = metadata['full_name']?.toString().trim();
  final String? name = metadata['name']?.toString().trim();

  return User(
    id: supabaseUser.id,
    email: supabaseUser.email,
    displayName: (fullName?.isNotEmpty ?? false)
        ? fullName
        : ((name?.isNotEmpty ?? false) ? name : null),
    emailVerified: supabaseUser.emailConfirmedAt != null,
  );
}
