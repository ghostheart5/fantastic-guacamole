import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    show intelligenceStateProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingCompleteGuardProvider = Provider<bool>(
  (ref) => ref.watch(onboardingCompleteProvider),
);

final authenticatedGuardProvider = Provider<bool>((ref) {
  final intelligence = ref.watch(intelligenceStateProvider);
  return intelligence.auth.isAuthenticated ||
      intelligence.flags.mockLoginEnabled ||
      intelligence.flags.testerFullAccess;
});
