import 'package:fantastic_guacamole/features/monetization/data/models/models.dart'
    as feature_models;
import 'package:fantastic_guacamole/features/monetization/data/repositories/ai_credit_repository.dart'
    as feature_repos;
import 'package:fantastic_guacamole/features/monetization/data/repositories/entitlement_repository.dart'
    as feature_repos;
import 'package:fantastic_guacamole/features/monetization/data/repositories/purchase_repository.dart'
    as feature_repos;
import 'package:fantastic_guacamole/features/monetization/data/repositories/subscription_repository.dart'
    as feature_repos;
import 'package:fantastic_guacamole/features/monetization/data/services/monetization_connector_actions.dart'
    as feature_actions;
import 'package:fantastic_guacamole/features/monetization/domain/purchase_operation_result.dart';
import 'package:fantastic_guacamole/features/monetization/integration/monetization_actions_compat.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_package.dart'
    as legacy_models;
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_transaction.dart'
    as legacy_models;
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart'
    as legacy_models;
import 'package:fantastic_guacamole/features/monetization/models/entitlement_event.dart'
    as legacy_models;
import 'package:fantastic_guacamole/features/monetization/models/subscription_plan.dart'
    as legacy_models;
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart'
    as legacy_models;
import 'package:fantastic_guacamole/features/monetization/repositories/ai_credit_repository.dart'
    as legacy_repos;
import 'package:fantastic_guacamole/features/monetization/repositories/purchase_repository.dart'
    as legacy_repos;
import 'package:fantastic_guacamole/features/monetization/repositories/subscription_repository.dart'
    as legacy_repos;
import 'package:fantastic_guacamole/features/monetization/services/monetization_connector_actions.dart'
    as legacy_actions;
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _FeatureSubRepo implements feature_repos.SubscriptionRepository {
  @override
  Future<feature_models.UserSubscription?> getCurrentSubscription() async {
    return const feature_models.UserSubscription(
      userId: 'u1',
      planId: 'premium_monthly',
      productId: 'chronospark_premium_monthly',
      status: 'active',
      isActive: true,
      autoRenews: true,
      source: 'supabase',
      periodCredits: 250,
    );
  }

  @override
  Future<List<feature_models.SubscriptionPlan>> getSubscriptionPlans() async {
    return const <feature_models.SubscriptionPlan>[
      feature_models.SubscriptionPlan(
        id: 'premium_monthly',
        name: 'Premium Monthly',
        productId: 'chronospark_premium_monthly',
        planType: 'subscription',
        priceMicros: 9990000,
        currencyCode: 'USD',
        billingPeriod: 'monthly',
        creditsPerPeriod: 250,
        isActive: true,
      ),
    ];
  }
}

class _FeatureAiRepo implements feature_repos.AiCreditRepository {
  @override
  Future<feature_models.AiCreditWallet?> consumeCredits({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    return const feature_models.AiCreditWallet(
      userId: 'u1',
      balance: 100,
      allowanceRemaining: 100,
      bonusBalance: 0,
      periodCredits: 250,
      lifetimeEarned: 250,
      lifetimeSpent: 150,
      tier: 'premium',
    );
  }

  @override
  Future<List<feature_models.AiCreditPackage>> getCreditPackages() async {
    return const <feature_models.AiCreditPackage>[
      feature_models.AiCreditPackage(
        id: 'credits_100',
        productId: 'chronospark_credits_100',
        name: '100 Credits',
        credits: 100,
        bonusCredits: 0,
        priceMicros: 1990000,
        currencyCode: 'USD',
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<feature_models.AiCreditPurchase>> getPurchaseHistory({
    int limit = 50,
  }) async {
    return const <feature_models.AiCreditPurchase>[];
  }

  @override
  Future<List<feature_models.AiCreditTransaction>> getTransactions({
    int limit = 50,
  }) async {
    return const <feature_models.AiCreditTransaction>[];
  }

  @override
  Future<feature_models.AiCreditWallet?> getWallet() async {
    return const feature_models.AiCreditWallet(
      userId: 'u1',
      balance: 200,
      allowanceRemaining: 200,
      bonusBalance: 0,
      periodCredits: 250,
      lifetimeEarned: 250,
      lifetimeSpent: 50,
      tier: 'premium',
    );
  }
}

class _FeatureEntRepo implements feature_repos.EntitlementRepository {
  @override
  Future<List<feature_models.EntitlementEvent>> getEntitlementEvents({
    int limit = 30,
  }) async {
    return const <feature_models.EntitlementEvent>[];
  }

  @override
  Future<feature_models.PremiumEntitlement> getPremiumEntitlement() async {
    return const feature_models.PremiumEntitlement(
      isPremium: true,
      isActive: true,
      planId: 'premium_monthly',
      source: 'supabase',
    );
  }
}

class _FeaturePurchaseRepo implements feature_repos.PurchaseRepository {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      const Stream<List<PurchaseDetails>>.empty();

  @override
  Future<feature_repos.PurchaseResult> purchaseCredits(
    feature_models.AiCreditPackage pack,
  ) async {
    return feature_repos.PurchaseResult(
      success: true,
      productId: pack.productId,
      message: 'ok',
    );
  }

  @override
  Future<feature_repos.PurchaseResult> purchaseSubscription(
    feature_models.SubscriptionPlan plan,
  ) async {
    return feature_repos.PurchaseResult(
      success: true,
      productId: plan.productId,
      message: 'ok',
    );
  }

  @override
  Future<feature_repos.PurchaseResult> restorePurchases() async {
    return const feature_repos.PurchaseResult(
      success: true,
      productId: '__restore__',
      message: 'restored',
    );
  }
}

class _LegacySubRepo implements legacy_repos.SubscriptionRepository {
  @override
  Future<List<legacy_models.EntitlementEvent>> getEntitlementEvents() async {
    return <legacy_models.EntitlementEvent>[
      legacy_models.EntitlementEvent(
        id: 'e1',
        eventType: 'activated',
        planId: 'premium_monthly',
        productId: 'chronospark_premium_monthly',
        isActive: true,
        effectiveAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<legacy_models.SubscriptionStatus> getSubscriptionStatus() async {
    return const legacy_models.SubscriptionStatus(
      planId: 'premium_monthly',
      productId: 'chronospark_premium_monthly',
      status: 'active',
      source: 'supabase',
      isActive: true,
      isPremium: true,
      autoRenews: true,
      periodCredits: 250,
    );
  }
}

class _LegacyAiRepo implements legacy_repos.AiCreditRepository {
  @override
  Future<legacy_models.AiCreditWallet> consumeCredits({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    return legacy_models.AiCreditWallet.free();
  }

  @override
  Future<List<legacy_models.AiCreditTransaction>> getCreditHistory() async {
    return const <legacy_models.AiCreditTransaction>[];
  }

  @override
  Future<legacy_models.AiCreditWallet> getWallet() async {
    return legacy_models.AiCreditWallet.free();
  }
}

class _LegacyPurchaseRepo implements legacy_repos.PurchaseRepository {
  @override
  void dispose() {}

  @override
  Future<PurchaseOperationResult> restorePurchases() async {
    return const PurchaseOperationResult(
      success: true,
      message: 'restored',
      productId: '__restore__',
    );
  }

  @override
  Future<PurchaseOperationResult> startCreditPurchase(
    legacy_models.AiCreditPackage pack,
  ) async {
    return PurchaseOperationResult(
      success: true,
      message: 'credits',
      productId: pack.productId,
    );
  }

  @override
  Future<PurchaseOperationResult> startSubscriptionPurchase(
    legacy_models.SubscriptionPlan plan,
  ) async {
    return PurchaseOperationResult(
      success: true,
      message: 'sub',
      productId: plan.productId ?? plan.id,
    );
  }
}

void main() {
  group('MonetizationActionsCompat adapters', () {
    test('feature adapter returns normalized status', () async {
      final feature_actions.MonetizationConnectorActions actions =
          feature_actions.MonetizationConnectorActions(
            subscriptionRepository: _FeatureSubRepo(),
            aiCreditRepository: _FeatureAiRepo(),
            entitlementRepository: _FeatureEntRepo(),
            purchaseRepository: _FeaturePurchaseRepo(),
          );
      final MonetizationActionsCompat adapter =
          FeatureMonetizationActionsCompat(actions);

      final MonetizationStatusSnapshot snapshot = await adapter.fetchStatus();
      expect(snapshot.stackType, MonetizationStackType.feature);
      expect(snapshot.isPremium, isTrue);
      expect(snapshot.walletBalance, 200);
    });

    test('legacy adapter routes purchase and restore', () async {
      final legacy_actions.MonetizationConnectorActions actions =
          legacy_actions.MonetizationConnectorActions(
            subscriptionRepository: _LegacySubRepo(),
            aiCreditRepository: _LegacyAiRepo(),
            purchaseRepository: _LegacyPurchaseRepo(),
          );
      final MonetizationActionsCompat adapter = LegacyMonetizationActionsCompat(
        actions,
      );

      final MonetizationPurchaseOutcome purchase = await adapter
          .purchaseCreditsByProductId('chronospark_credits_100');
      final MonetizationPurchaseOutcome restore = await adapter
          .restorePurchases();

      expect(purchase.success, isTrue);
      expect(restore.productId, '__restore__');
    });
  });
}
