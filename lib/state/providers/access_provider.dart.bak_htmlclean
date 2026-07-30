import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppAccessState {
  const AppAccessState({
    required this.hasPremiumAccess,
    required this.hasTesterFullAccess,
    required this.paywallDisabled,
  });

  final bool hasPremiumAccess;
  final bool hasTesterFullAccess;
  final bool paywallDisabled;

  bool get paywallEnabled => !paywallDisabled && !hasTesterFullAccess;

  String get subscriptionStatusLabel {
    if (paywallDisabled || hasTesterFullAccess) {
      return 'Unlocked for testing';
    }
    if (hasPremiumAccess) {
      return 'Premium active';
    }
    return 'Premium locked';
  }

  String get subscriptionStatusDetail {
    if (paywallDisabled || hasTesterFullAccess) {
      return 'This QA build bypasses premium restrictions and does not use live billing.';
    }
    if (hasPremiumAccess) {
      return 'Premium features are currently unlocked for this account.';
    }
    return 'Premium access is not yet provisioned in this build.';
  }
}

final runtimePremiumAccessProvider =
    NotifierProvider<RuntimePremiumAccessNotifier, bool>(
      RuntimePremiumAccessNotifier.new,
    );

class RuntimePremiumAccessNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final appAccessProvider = Provider<AppAccessState>((ref) {
  final intelligence = ref.watch(intelligenceStateProvider);
  final bool testerFullAccess =
      intelligence.flags.testerFullAccess ||
      intelligence.flags.mockMode ||
      intelligence.flags.paywallDisabled;
  final bool runtimePremiumAccess = ref.watch(runtimePremiumAccessProvider);
  final bool monetizationPremiumAccess = ref.watch(premiumAccessProvider);

  return AppAccessState(
    hasPremiumAccess:
        testerFullAccess || runtimePremiumAccess || monetizationPremiumAccess,
    hasTesterFullAccess: testerFullAccess,
    paywallDisabled: intelligence.flags.paywallDisabled,
  );
});
