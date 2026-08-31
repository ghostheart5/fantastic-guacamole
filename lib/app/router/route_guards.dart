import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    show intelligenceStateProvider;
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isQaVisualPreview(IntelligenceState intelligence) =>
    intelligence.flags.mockMode &&
    intelligence.flags.testerFullAccess &&
    intelligence.auth.isAuthenticated;

final onboardingCompleteGuardProvider = Provider<bool>((ref) {
  final intelligence = ref.watch(intelligenceStateProvider);
  return _isQaVisualPreview(intelligence) ||
      (ref.watch(accountOnboardingCompleteProvider).asData?.value ?? false);
});

final onboardingWelcomeCompleteGuardProvider = Provider<bool>((ref) {
  final intelligence = ref.watch(intelligenceStateProvider);
  return _isQaVisualPreview(intelligence) ||
      ref.watch(onboardingWelcomeCompleteProvider);
});

final authenticatedGuardProvider = Provider<bool>((ref) {
  final intelligence = ref.watch(intelligenceStateProvider);
  final accountScope = ref.watch(accountStorageScopeProvider);
  return intelligence.auth.isAuthenticated && accountScope.isWritable;
});
