import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/analytics_events.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool> canUsePremiumFeature(Ref ref) async {
  final entitlement = await ref.read(premiumEntitlementProvider.future);
  final bool allowed = entitlement.isPremium && entitlement.isActive;
  AppAnalytics.track(
    allowed
        ? MonetizationEvents.premiumFeatureUnlocked
        : MonetizationEvents.premiumFeatureBlocked,
  );
  return allowed;
}

Future<bool> canUseSiEngine(Ref ref) async {
  return canUsePremiumFeature(ref);
}

Future<bool> canUseSmartCoach(Ref ref) async {
  return canUsePremiumFeature(ref);
}

Future<bool> canSpendCredits(Ref ref, {required int amount}) async {
  final wallet = await ref.read(aiCreditWalletProvider.future);
  return wallet != null && wallet.balance >= amount;
}

Future<void> requireCredits(Ref ref, {required int amount}) async {
  final bool allowed = await canSpendCredits(ref, amount: amount);
  if (!allowed) {
    AppAnalytics.track(MonetizationEvents.creditsInsufficient);
    throw StateError('Insufficient AI credits.');
  }
}

Future<void> requirePremium(Ref ref) async {
  final bool allowed = await canUsePremiumFeature(ref);
  if (!allowed) {
    throw StateError('Premium entitlement required.');
  }
}
