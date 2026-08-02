import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    show intelligenceStateProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingCompleteGuardProvider = Provider<bool>(
  (ref) => ref.watch(onboardingCompleteProvider),
);

final onboardingStatusGuardProvider = Provider<OnboardingStatus>((ref) {
  return ref.watch(onboardingStatusProvider);
});

final onboardingResolvedGuardProvider = Provider<bool>((ref) {
  return ref.watch(onboardingStatusGuardProvider) != OnboardingStatus.unknown;
});

final authenticatedGuardProvider = Provider<bool>((ref) {
  final intelligence = ref.watch(intelligenceStateProvider);
  return intelligence.auth.isAuthenticated;
});

final profileCompleteGuardProvider = Provider<bool>((ref) {
  final profile = ref.watch(profileProvider);
  return profile.hasValidProfile;
});

final premiumAccessGuardProvider = Provider<bool>((ref) {
  final access = ref.watch(appAccessProvider);
  return access.hasPremiumAccess || !access.paywallEnabled;
});

final adminAccessGuardProvider = Provider<bool>((ref) {
  final intelligence = ref.watch(intelligenceStateProvider);
  return intelligence.flags.testerFullAccess;
});
