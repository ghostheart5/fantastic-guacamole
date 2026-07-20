import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/analytics_events.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreditStoreControllerState {
  const CreditStoreControllerState({
    this.isBusy = false,
    this.activeProductId,
    this.error,
    this.lastSuccess = false,
  });

  final bool isBusy;
  final String? activeProductId;
  final String? error;
  final bool lastSuccess;

  CreditStoreControllerState copyWith({
    bool? isBusy,
    String? activeProductId,
    String? error,
    bool? lastSuccess,
  }) {
    return CreditStoreControllerState(
      isBusy: isBusy ?? this.isBusy,
      activeProductId: activeProductId ?? this.activeProductId,
      error: error,
      lastSuccess: lastSuccess ?? this.lastSuccess,
    );
  }
}

class CreditStoreController extends Notifier<CreditStoreControllerState> {
  @override
  CreditStoreControllerState build() => const CreditStoreControllerState();

  Future<void> purchasePack(AiCreditPackage pack) async {
    AppAnalytics.track(MonetizationEvents.creditPackSelected);
    state = state.copyWith(
      isBusy: true,
      activeProductId: pack.productId,
      error: null,
      lastSuccess: false,
    );

    final PurchaseResult result =
        await ref.read(purchaseRepositoryProvider).purchaseCredits(pack);

    state = state.copyWith(
      isBusy: false,
      activeProductId: null,
      error: result.success ? null : result.message,
      lastSuccess: result.success,
    );

    if (result.success) {
      ref.invalidate(aiCreditWalletProvider);
      ref.invalidate(aiCreditTransactionsProvider);
      ref.invalidate(purchaseHistoryProvider);
    }
  }
}

final creditStoreControllerProvider =
    NotifierProvider<CreditStoreController, CreditStoreControllerState>(
  CreditStoreController.new,
);
