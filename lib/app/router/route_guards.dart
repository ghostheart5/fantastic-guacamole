import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    show intelligenceStateProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingCompleteGuardProvider = Provider<bool>(
  (ref) => ref.watch(accountOnboardingCompleteProvider).asData?.value ?? false,
);

final onboardingWelcomeCompleteGuardProvider = Provider<bool>(
  (ref) => ref.watch(onboardingWelcomeCompleteProvider),
);

final authenticatedGuardProvider = Provider<bool>((ref) {
  final intelligence = ref.watch(intelligenceStateProvider);
  return intelligence.auth.isAuthenticated;
});
