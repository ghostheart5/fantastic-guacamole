import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    show
        authUserProvider,
        authenticatedGuardProvider,
        intelligenceStateProvider,
        mockLoginConfigProvider,
        mockAuthSessionProvider;

final onboardingCompleteGuardProvider = Provider<bool>(
  (ref) => ref.watch(onboardingCompleteProvider),
);

final premiumAccessGuardProvider = Provider<bool>(
  (ref) => ref.watch(appAccessProvider).hasPremiumAccess,
);
