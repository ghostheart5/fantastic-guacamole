import 'package:fantastic_guacamole/features/monetization/domain/purchase_operation_result.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_package.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_transaction.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/monetization/models/entitlement_event.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_plan.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/ai_credit_repository.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/subscription_repository.dart';

/// Canonical connector action facade for the legacy monetization stack.
class MonetizationConnectorActions {
  const MonetizationConnectorActions({
    required SubscriptionRepository subscriptionRepository,
    required AiCreditRepository aiCreditRepository,
    required PurchaseRepository purchaseRepository,
  }) : _subscriptionRepository = subscriptionRepository,
       _aiCreditRepository = aiCreditRepository,
       _purchaseRepository = purchaseRepository;

  final SubscriptionRepository _subscriptionRepository;
  final AiCreditRepository _aiCreditRepository;
  final PurchaseRepository _purchaseRepository;

  Future<SubscriptionStatus> fetchSubscriptionStatus() {
    return _subscriptionRepository.getSubscriptionStatus();
  }

  Future<List<EntitlementEvent>> fetchEntitlementEvents() {
    return _subscriptionRepository.getEntitlementEvents();
  }

  Future<AiCreditWallet> fetchWallet() {
    return _aiCreditRepository.getWallet();
  }

  Future<List<AiCreditTransaction>> fetchCreditHistory() {
    return _aiCreditRepository.getCreditHistory();
  }

  Future<AiCreditWallet> consumeCredits({
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

  Future<PurchaseOperationResult> purchasePlanById(
    SubscriptionPlan plan,
  ) {
    return _purchaseRepository.startSubscriptionPurchase(plan);
  }

  Future<PurchaseOperationResult> purchaseCreditsById(AiCreditPackage pack) {
    return _purchaseRepository.startCreditPurchase(pack);
  }

  Future<PurchaseOperationResult> restorePurchases() {
    return _purchaseRepository.restorePurchases();
  }
}
