import 'package:fantastic_guacamole/features/monetization/data/models/models.dart'
    as feature_models;
import 'package:fantastic_guacamole/features/monetization/data/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/monetization_connector_actions.dart'
    as feature_actions;
import 'package:fantastic_guacamole/features/monetization/domain/purchase_operation_result.dart';
import 'package:fantastic_guacamole/features/monetization/domain/monetization_catalog.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_package.dart'
    as legacy_models;
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart'
    as legacy_models;
import 'package:fantastic_guacamole/features/monetization/models/subscription_plan.dart'
    as legacy_models;
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart'
    as legacy_models;
import 'package:fantastic_guacamole/features/monetization/services/monetization_connector_actions.dart'
    as legacy_actions;

enum MonetizationStackType { feature, legacy }

class MonetizationPlanOption {
  const MonetizationPlanOption({
    required this.id,
    required this.productId,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String productId;
  final String name;
  final bool isActive;
}

class MonetizationCreditOption {
  const MonetizationCreditOption({
    required this.id,
    required this.productId,
    required this.name,
    required this.totalCredits,
    required this.isActive,
  });

  final String id;
  final String productId;
  final String name;
  final int totalCredits;
  final bool isActive;
}

class MonetizationStatusSnapshot {
  const MonetizationStatusSnapshot({
    required this.planId,
    required this.isPremium,
    required this.isActive,
    required this.walletBalance,
    required this.stackType,
  });

  final String planId;
  final bool isPremium;
  final bool isActive;
  final int walletBalance;
  final MonetizationStackType stackType;
}

class MonetizationPurchaseOutcome {
  const MonetizationPurchaseOutcome({
    required this.success,
    required this.productId,
    required this.message,
  });

  final bool success;
  final String productId;
  final String message;
}

abstract class MonetizationActionsCompat {
  MonetizationStackType get stackType;

  Future<MonetizationStatusSnapshot> fetchStatus();

  Future<List<MonetizationPlanOption>> fetchPlanOptions();

  Future<List<MonetizationCreditOption>> fetchCreditOptions();

  Future<MonetizationPurchaseOutcome> purchaseSubscriptionByProductId(
    String productId,
  );

  Future<MonetizationPurchaseOutcome> purchaseCreditsByProductId(
    String productId,
  );

  Future<MonetizationPurchaseOutcome> restorePurchases();
}

class FeatureMonetizationActionsCompat implements MonetizationActionsCompat {
  const FeatureMonetizationActionsCompat(this._actions);

  final feature_actions.MonetizationConnectorActions _actions;

  @override
  MonetizationStackType get stackType => MonetizationStackType.feature;

  @override
  Future<List<MonetizationCreditOption>> fetchCreditOptions() async {
    final List<feature_models.AiCreditPackage> packs = await _actions
        .fetchCreditPackages();
    return packs
        .map(
          (feature_models.AiCreditPackage pack) => MonetizationCreditOption(
            id: pack.id,
            productId: pack.productId,
            name: pack.name,
            totalCredits: pack.totalCredits,
            isActive: pack.isActive,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<MonetizationPlanOption>> fetchPlanOptions() async {
    final List<feature_models.SubscriptionPlan> plans = await _actions
        .fetchPlans();
    return plans
        .map(
          (feature_models.SubscriptionPlan plan) => MonetizationPlanOption(
            id: plan.id,
            productId: plan.productId,
            name: plan.name,
            isActive: plan.isActive,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<MonetizationStatusSnapshot> fetchStatus() async {
    final feature_models.UserSubscription? subscription = await _actions
        .fetchSubscriptionStatus();
    final feature_models.PremiumEntitlement entitlement = await _actions
        .fetchPremiumEntitlement();
    final feature_models.AiCreditWallet? wallet = await _actions.fetchWallet();
    return MonetizationStatusSnapshot(
      planId: subscription?.planId ?? entitlement.planId,
      isPremium: entitlement.isPremium,
      isActive: entitlement.isActive,
      walletBalance: wallet?.balance ?? 0,
      stackType: stackType,
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> purchaseCreditsByProductId(
    String productId,
  ) async {
    final List<feature_models.AiCreditPackage> packs = await _actions
        .fetchCreditPackages();
    final feature_models.AiCreditPackage? target = packs
        .where(
          (feature_models.AiCreditPackage item) => item.productId == productId,
        )
        .cast<feature_models.AiCreditPackage?>()
        .firstWhere(
          (feature_models.AiCreditPackage? item) => item != null,
          orElse: () => null,
        );
    if (target == null) {
      return MonetizationPurchaseOutcome(
        success: false,
        productId: productId,
        message: 'Credit pack was not found for product id: $productId',
      );
    }
    final PurchaseResult result = await _actions.purchaseCredits(target);
    return MonetizationPurchaseOutcome(
      success: result.success,
      productId: result.productId,
      message: result.message ?? (result.success ? 'OK' : 'Failed'),
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> purchaseSubscriptionByProductId(
    String productId,
  ) async {
    final List<feature_models.SubscriptionPlan> plans = await _actions
        .fetchPlans();
    final feature_models.SubscriptionPlan? target = plans
        .where(
          (feature_models.SubscriptionPlan item) => item.productId == productId,
        )
        .cast<feature_models.SubscriptionPlan?>()
        .firstWhere(
          (feature_models.SubscriptionPlan? item) => item != null,
          orElse: () => null,
        );
    if (target == null) {
      return MonetizationPurchaseOutcome(
        success: false,
        productId: productId,
        message: 'Subscription plan was not found for product id: $productId',
      );
    }
    final PurchaseResult result = await _actions.purchaseSubscription(target);
    return MonetizationPurchaseOutcome(
      success: result.success,
      productId: result.productId,
      message: result.message ?? (result.success ? 'OK' : 'Failed'),
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> restorePurchases() async {
    final PurchaseResult result = await _actions.restorePurchases();
    return MonetizationPurchaseOutcome(
      success: result.success,
      productId: result.productId,
      message: result.message ?? (result.success ? 'OK' : 'Failed'),
    );
  }
}

class LegacyMonetizationActionsCompat implements MonetizationActionsCompat {
  const LegacyMonetizationActionsCompat(this._actions);

  final legacy_actions.MonetizationConnectorActions _actions;

  @override
  MonetizationStackType get stackType => MonetizationStackType.legacy;

  @override
  Future<List<MonetizationCreditOption>> fetchCreditOptions() async {
    return MonetizationCatalog.creditPackages
        .map(
          (legacy_models.AiCreditPackage pack) => MonetizationCreditOption(
            id: pack.id,
            productId: pack.productId,
            name: pack.title,
            totalCredits: pack.credits + pack.bonusCredits,
            isActive: pack.isAvailable,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<MonetizationPlanOption>> fetchPlanOptions() async {
    return MonetizationCatalog.plans
        .where((legacy_models.SubscriptionPlan item) => item.productId != null)
        .map(
          (legacy_models.SubscriptionPlan plan) => MonetizationPlanOption(
            id: plan.id,
            productId: plan.productId ?? plan.id,
            name: plan.title,
            isActive: plan.isAvailable,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<MonetizationStatusSnapshot> fetchStatus() async {
    final legacy_models.SubscriptionStatus status = await _actions
        .fetchSubscriptionStatus();
    final legacy_models.AiCreditWallet wallet = await _actions.fetchWallet();
    return MonetizationStatusSnapshot(
      planId: status.planId,
      isPremium: status.isPremium,
      isActive: status.isActive,
      walletBalance: wallet.balance,
      stackType: stackType,
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> purchaseCreditsByProductId(
    String productId,
  ) async {
    final legacy_models.AiCreditPackage? target = MonetizationCatalog
        .creditPackages
        .where(
          (legacy_models.AiCreditPackage item) => item.productId == productId,
        )
        .cast<legacy_models.AiCreditPackage?>()
        .firstWhere(
          (legacy_models.AiCreditPackage? item) => item != null,
          orElse: () => null,
        );
    if (target == null) {
      return MonetizationPurchaseOutcome(
        success: false,
        productId: productId,
        message: 'Credit pack was not found for product id: $productId',
      );
    }
    final PurchaseOperationResult result = await _actions.purchaseCreditsById(
      target,
    );
    return MonetizationPurchaseOutcome(
      success: result.success,
      productId: result.productId,
      message: result.message,
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> purchaseSubscriptionByProductId(
    String productId,
  ) async {
    final legacy_models.SubscriptionPlan? target = MonetizationCatalog.plans
        .where(
          (legacy_models.SubscriptionPlan item) => item.productId == productId,
        )
        .cast<legacy_models.SubscriptionPlan?>()
        .firstWhere(
          (legacy_models.SubscriptionPlan? item) => item != null,
          orElse: () => null,
        );
    if (target == null) {
      return MonetizationPurchaseOutcome(
        success: false,
        productId: productId,
        message: 'Subscription plan was not found for product id: $productId',
      );
    }
    final PurchaseOperationResult result = await _actions.purchasePlanById(
      target,
    );
    return MonetizationPurchaseOutcome(
      success: result.success,
      productId: result.productId,
      message: result.message,
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> restorePurchases() async {
    final PurchaseOperationResult result = await _actions.restorePurchases();
    return MonetizationPurchaseOutcome(
      success: result.success,
      productId: result.productId,
      message: result.message,
    );
  }
}
