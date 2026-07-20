import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/analytics_events.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaywallControllerState {
  const PaywallControllerState({
    this.isBusy = false,
    this.activeProductId,
    this.error,
    this.lastSuccess = false,
  });

  final bool isBusy;
  final String? activeProductId;
  final String? error;
  final bool lastSuccess;

  PaywallControllerState copyWith({
    bool? isBusy,
    String? activeProductId,
    String? error,
    bool? lastSuccess,
  }) {
    return PaywallControllerState(
      isBusy: isBusy ?? this.isBusy,
      activeProductId: activeProductId ?? this.activeProductId,
      error: error,
      lastSuccess: lastSuccess ?? this.lastSuccess,
    );
  }
}

class PaywallController extends Notifier<PaywallControllerState> {
  @override
  PaywallControllerState build() => const PaywallControllerState();

  Future<void> purchasePlan(SubscriptionPlan plan) async {
    AppAnalytics.track(MonetizationEvents.subscriptionPlanSelected);
    state = state.copyWith(
      isBusy: true,
      activeProductId: plan.productId,
      error: null,
      lastSuccess: false,
    );

    final PurchaseResult result =
        await ref.read(purchaseRepositoryProvider).purchaseSubscription(plan);

    state = state.copyWith(
      isBusy: false,
      activeProductId: null,
      error: result.success ? null : result.message,
      lastSuccess: result.success,
    );

    if (result.success) {
      ref.invalidate(premiumEntitlementProvider);
      ref.invalidate(currentSubscriptionProvider);
      ref.invalidate(aiCreditWalletProvider);
      AppAnalytics.track(MonetizationEvents.premiumFeatureUnlocked);
    }
  }
}

final paywallControllerProvider =
    NotifierProvider<PaywallController, PaywallControllerState>(
  PaywallController.new,
);
