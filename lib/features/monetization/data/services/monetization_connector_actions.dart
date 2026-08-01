import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/ai_credit_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/entitlement_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/subscription_repository.dart';

/// Canonical app-level monetization connector surface.
///
/// This provides a single reusable action catalog for plans, entitlement,
/// wallet, credit consumption, and purchase execution.
class MonetizationConnectorActions {
  const MonetizationConnectorActions({
    required this._subscriptionRepository,
    required this._aiCreditRepository,
    required this._entitlementRepository,
    required this._purchaseRepository,
  });

  final SubscriptionRepository _subscriptionRepository;
  final AiCreditRepository _aiCreditRepository;
  final EntitlementRepository _entitlementRepository;
  final PurchaseRepository _purchaseRepository;

  Future<List<SubscriptionPlan>> fetchPlans() {
    return _subscriptionRepository.getSubscriptionPlans();
  }

  Future<UserSubscription?> fetchSubscriptionStatus() {
    return _subscriptionRepository.getCurrentSubscription();
  }

  Future<PremiumEntitlement> fetchPremiumEntitlement() {
    return _entitlementRepository.getPremiumEntitlement();
  }

  Future<List<AiCreditPackage>> fetchCreditPackages() {
    return _aiCreditRepository.getCreditPackages();
  }

  Future<AiCreditWallet?> fetchWallet() {
    return _aiCreditRepository.getWallet();
  }

  Future<List<AiCreditTransaction>> fetchTransactions({int limit = 50}) {
    return _aiCreditRepository.getTransactions(limit: limit);
  }

  Future<List<AiCreditPurchase>> fetchPurchaseHistory({int limit = 50}) {
    return _aiCreditRepository.getPurchaseHistory(limit: limit);
  }

  Future<AiCreditWallet?> consumeCredits({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return _aiCreditRepository.consumeCredits(
      amount: amount,
      reason: reason,
      metadata: metadata,
    );
  }

  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan) {
    return _purchaseRepository.purchaseSubscription(plan);
  }

  Future<PurchaseResult> purchaseCredits(AiCreditPackage pack) {
    return _purchaseRepository.purchaseCredits(pack);
  }

  Future<PurchaseResult> restorePurchases() {
    return _purchaseRepository.restorePurchases();
  }
}
