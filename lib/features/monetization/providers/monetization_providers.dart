import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/features/monetization/data/monetization_remote_data_source.dart';
import 'package:fantastic_guacamole/features/monetization/domain/monetization_catalog.dart';
import 'package:fantastic_guacamole/features/monetization/domain/paywall_content.dart';
import 'package:fantastic_guacamole/features/monetization/domain/purchase_operation_result.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_transaction.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/monetization/models/entitlement_event.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/ai_credit_repository.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/subscription_repository.dart';
import 'package:fantastic_guacamole/features/monetization/services/billing_service.dart';
import 'package:fantastic_guacamole/features/monetization/services/credit_service.dart'
    as monetization;
import 'package:fantastic_guacamole/features/monetization/services/entitlement_service.dart';
import 'package:fantastic_guacamole/features/monetization/services/paywall_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final monetizationRemoteDataSourceProvider =
    Provider<MonetizationRemoteDataSource>((Ref ref) {
      return MonetizationRemoteDataSource(ref.watch(supabaseClientProvider));
    });

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((Ref ref) {
  return SupabaseSubscriptionRepository(
    ref.watch(monetizationRemoteDataSourceProvider),
  );
});

final aiCreditRepositoryProvider = Provider<AiCreditRepository>((Ref ref) {
  return SupabaseAiCreditRepository(ref.watch(monetizationRemoteDataSourceProvider));
});

final billingServiceProvider = Provider<BillingService>((Ref ref) {
  return BillingService();
});

final purchaseRepositoryProvider = Provider<PurchaseRepository>((Ref ref) {
  final GooglePlayPurchaseRepository repository = GooglePlayPurchaseRepository(
    ref.watch(billingServiceProvider),
    ref.watch(subscriptionRepositoryProvider),
    ref.watch(aiCreditRepositoryProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final entitlementServiceProvider = Provider<EntitlementService>((Ref ref) {
  return EntitlementService(ref.watch(subscriptionRepositoryProvider));
});

final monetizationCreditServiceProvider = Provider<monetization.CreditService>((Ref ref) {
  return monetization.CreditService(ref.watch(aiCreditRepositoryProvider));
});

final monetizationPaywallServiceProvider = Provider<PaywallService>((Ref ref) {
  return PaywallService(
    ref.watch(subscriptionRepositoryProvider),
    ref.watch(aiCreditRepositoryProvider),
    ref.watch(billingServiceProvider),
  );
});

class SubscriptionController extends AsyncNotifier<SubscriptionStatus> {
  @override
  Future<SubscriptionStatus> build() {
    return ref.read(entitlementServiceProvider).refreshEntitlements();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(
      await ref.read(entitlementServiceProvider).refreshEntitlements(),
    );
  }
}

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionController, SubscriptionStatus>(
      SubscriptionController.new,
    );

class WalletController extends AsyncNotifier<AiCreditWallet> {
  @override
  Future<AiCreditWallet> build() {
    return ref.read(monetizationCreditServiceProvider).loadWallet();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(
      await ref.read(monetizationCreditServiceProvider).loadWallet(),
    );
  }
}

final walletProvider = AsyncNotifierProvider<WalletController, AiCreditWallet>(
  WalletController.new,
);

class CreditHistoryController extends AsyncNotifier<List<AiCreditTransaction>> {
  @override
  Future<List<AiCreditTransaction>> build() {
    return ref.read(monetizationCreditServiceProvider).loadHistory();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(
      await ref.read(monetizationCreditServiceProvider).loadHistory(),
    );
  }
}

final creditHistoryProvider =
    AsyncNotifierProvider<CreditHistoryController, List<AiCreditTransaction>>(
      CreditHistoryController.new,
    );

final entitlementEventsProvider = FutureProvider<List<EntitlementEvent>>((Ref ref) {
  return ref.read(entitlementServiceProvider).loadEvents();
});

final paywallProvider = FutureProvider<PaywallContent>((Ref ref) async {
  return ref.read(monetizationPaywallServiceProvider).build();
});

final premiumAccessProvider = Provider<bool>((Ref ref) {
  return ref.watch(subscriptionProvider).maybeWhen(
    data: (SubscriptionStatus status) => status.isPremium && status.isActive,
    orElse: () => false,
  );
});

class PurchaseControllerState {
  const PurchaseControllerState({
    this.isBusy = false,
    this.activeProductId,
    this.message,
    this.lastResult,
  });

  final bool isBusy;
  final String? activeProductId;
  final String? message;
  final PurchaseOperationResult? lastResult;

  PurchaseControllerState copyWith({
    bool? isBusy,
    String? activeProductId,
    String? message,
    PurchaseOperationResult? lastResult,
  }) {
    return PurchaseControllerState(
      isBusy: isBusy ?? this.isBusy,
      activeProductId: activeProductId ?? this.activeProductId,
      message: message ?? this.message,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class PurchaseController extends Notifier<PurchaseControllerState> {
  @override
  PurchaseControllerState build() => const PurchaseControllerState();

  Future<PurchaseOperationResult> purchasePlan(String planId) async {
    final plan = MonetizationCatalog.plans.firstWhere(
      (item) => item.id == planId,
    );
    state = state.copyWith(isBusy: true, activeProductId: plan.productId);
    final PurchaseOperationResult result = await (() async {
      try {
        return await ref
            .read(purchaseRepositoryProvider)
            .startSubscriptionPurchase(plan);
      } on Object {
        return PurchaseOperationResult(
          success: false,
          message: 'Unable to start purchase flow. Please retry.',
          productId: plan.productId ?? plan.id,
        );
      }
    })();
    _afterPurchase(result);
    return result;
  }

  Future<PurchaseOperationResult> purchaseCredits(String packageId) async {
    final pack = MonetizationCatalog.creditPackages.firstWhere(
      (item) => item.id == packageId,
    );
    state = state.copyWith(isBusy: true, activeProductId: pack.productId);
    final PurchaseOperationResult result = await (() async {
      try {
        return await ref
            .read(purchaseRepositoryProvider)
            .startCreditPurchase(pack);
      } on Object {
        return PurchaseOperationResult(
          success: false,
          message: 'Unable to start credit purchase flow. Please retry.',
          productId: pack.productId,
        );
      }
    })();
    _afterPurchase(result);
    return result;
  }

  Future<PurchaseOperationResult> restorePurchases() async {
    state = state.copyWith(isBusy: true, activeProductId: '__restore__');
    final PurchaseOperationResult result = await (() async {
      try {
        return await ref.read(purchaseRepositoryProvider).restorePurchases();
      } on Object {
        return const PurchaseOperationResult(
          success: false,
          message: 'Unable to restore purchases right now. Please retry.',
          productId: '__restore__',
        );
      }
    })();
    _afterPurchase(result);
    return result;
  }

  void _afterPurchase(PurchaseOperationResult result) {
    if (result.success) {
      ref.invalidate(subscriptionProvider);
      ref.invalidate(walletProvider);
      ref.invalidate(creditHistoryProvider);
      ref.invalidate(paywallProvider);
      ref.invalidate(entitlementEventsProvider);
    }
    state = state.copyWith(
      isBusy: false,
      activeProductId: null,
      message: result.message,
      lastResult: result,
    );
  }
}

final purchaseProvider =
    NotifierProvider<PurchaseController, PurchaseControllerState>(
      PurchaseController.new,
    );