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
import 'package:fantastic_guacamole/features/monetization/services/monetization_connector_actions.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository(this._status, this._events);

  final SubscriptionStatus _status;
  final List<EntitlementEvent> _events;

  @override
  Future<List<EntitlementEvent>> getEntitlementEvents() async => _events;

  @override
  Future<SubscriptionStatus> getSubscriptionStatus() async => _status;
}

class _FakeAiCreditRepository implements AiCreditRepository {
  _FakeAiCreditRepository(this._wallet, this._history);

  final AiCreditWallet _wallet;
  final List<AiCreditTransaction> _history;

  @override
  Future<AiCreditWallet> consumeCredits({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    return AiCreditWallet(
      balance: _wallet.balance - amount,
      allowanceRemaining: _wallet.allowanceRemaining,
      bonusBalance: _wallet.bonusBalance,
      periodCredits: _wallet.periodCredits,
      lifetimeEarned: _wallet.lifetimeEarned,
      lifetimeSpent: _wallet.lifetimeSpent + amount,
      tier: _wallet.tier,
      updatedAt: _wallet.updatedAt,
      periodEndsAt: _wallet.periodEndsAt,
    );
  }

  @override
  Future<List<AiCreditTransaction>> getCreditHistory() async => _history;

  @override
  Future<AiCreditWallet> getWallet() async => _wallet;
}

class _FakePurchaseRepository implements PurchaseRepository {
  @override
  void dispose() {}

  @override
  Future<PurchaseOperationResult> restorePurchases() async {
    return const PurchaseOperationResult(
      success: true,
      message: 'restored',
      productId: '__restore__',
      restored: true,
    );
  }

  @override
  Future<PurchaseOperationResult> startCreditPurchase(AiCreditPackage pack) async {
    return PurchaseOperationResult(
      success: true,
      message: 'credits',
      productId: pack.productId,
    );
  }

  @override
  Future<PurchaseOperationResult> startSubscriptionPurchase(SubscriptionPlan plan) async {
    return PurchaseOperationResult(
      success: true,
      message: 'subscription',
      productId: plan.productId ?? plan.id,
    );
  }
}

void main() {
  group('MonetizationConnectorActions', () {
    final SubscriptionStatus status = SubscriptionStatus.free();
    final List<EntitlementEvent> events = <EntitlementEvent>[
      EntitlementEvent(
        id: 'e1',
        eventType: 'activated',
        planId: 'premium_monthly',
        productId: 'chronospark_premium_monthly',
        isActive: true,
        effectiveAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
    final AiCreditWallet wallet = AiCreditWallet.free();
    final List<AiCreditTransaction> history = <AiCreditTransaction>[];

    final MonetizationConnectorActions actions = MonetizationConnectorActions(
      subscriptionRepository: _FakeSubscriptionRepository(status, events),
      aiCreditRepository: _FakeAiCreditRepository(wallet, history),
      purchaseRepository: _FakePurchaseRepository(),
    );

    test('fetches status/events/wallet/history', () async {
      final SubscriptionStatus fetchedStatus = await actions.fetchSubscriptionStatus();
      final List<EntitlementEvent> fetchedEvents = await actions.fetchEntitlementEvents();
      final AiCreditWallet fetchedWallet = await actions.fetchWallet();
      final List<AiCreditTransaction> fetchedHistory = await actions.fetchCreditHistory();

      expect(fetchedStatus.planId, 'free');
      expect(fetchedEvents.length, 1);
      expect(fetchedWallet.balance, wallet.balance);
      expect(fetchedHistory, isEmpty);
    });

    test('routes purchase and restore actions', () async {
      const SubscriptionPlan plan = SubscriptionPlan(
        id: 'premium_monthly',
        kind: SubscriptionPlanKind.premiumMonthly,
        productId: 'chronospark_premium_monthly',
        title: 'Premium Monthly',
        subtitle: 'Monthly',
        priceLabel: '9.99',
        billingLabel: 'monthly',
        includedCredits: 250,
        featureIds: <String>['full_si_engine'],
      );
      const AiCreditPackage pack = AiCreditPackage(
        id: 'credits_100',
        productId: 'chronospark_credits_100',
        title: '100 Credits',
        credits: 100,
        bonusCredits: 0,
        priceLabel: '1.99',
        description: 'topup',
      );

      final PurchaseOperationResult sub = await actions.purchasePlanById(plan);
      final PurchaseOperationResult credit = await actions.purchaseCreditsById(pack);
      final PurchaseOperationResult restore = await actions.restorePurchases();

      expect(sub.success, isTrue);
      expect(credit.productId, pack.productId);
      expect(restore.restored, isTrue);
    });
  });
}
