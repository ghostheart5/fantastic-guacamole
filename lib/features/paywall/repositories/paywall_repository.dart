import 'package:fantastic_guacamole/config/paywall_config.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

class PaywallRepository implements IPaywallRepository {
  PaywallRepository() {
    _subscriptionState = SubscriptionState(
      isActive: paywallTestingMode,
      status: paywallTestingMode ? 'unlocked_for_testing' : 'locked',
      source: paywallTestingMode ? 'testing_mode' : 'mock_service',
      isTesting: paywallTestingMode,
    );
  }

  static const List<PaywallPlan> _plans = <PaywallPlan>[
    PaywallPlan(
      id: 'monthly',
      title: 'Premium Monthly',
      priceLabel: 'from \$9.99 / month',
      description: 'Best for active users who want full AI coaching and recurring credits.',
      aiCreditsIncluded: 300,
      benefits: <String>[
        '300 AI credits every month',
        'Priority AI responses',
        'Advanced memory and insights',
      ],
      isFeatured: true,
    ),
    PaywallPlan(
      id: 'annual',
      title: 'Premium Yearly',
      priceLabel: 'from \$89.99 / year',
      description: 'Best value for users committed to long-term habit building.',
      aiCreditsIncluded: 360,
      benefits: <String>[
        '360 AI credits every month',
        'Yearly billing discount',
        'Unlimited access to premium tools',
      ],
    ),
  ];

  static SubscriptionState _subscriptionState = const SubscriptionState(
    isActive: false,
    status: 'locked',
    source: 'mock_service',
  );

  @override
  Future<List<PaywallPlan>> getAvailablePlans() async {
    return _plans
        .map(
          (PaywallPlan plan) => PaywallPlan(
            id: plan.id,
            title: plan.title,
            priceLabel: plan.priceLabel,
            description: plan.description,
            aiCreditsIncluded: plan.aiCreditsIncluded,
            benefits: plan.benefits,
            isAvailable: true,
            isFeatured: plan.isFeatured,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<PaywallEntity> getPaywallConfig() async {
    return PaywallEntity(
      featureId: 'premium',
      title: paywallTestingMode ? 'Unlocked for testing' : 'AI Credits + Premium',
      body: paywallTestingMode
          ? 'Premium gates are bypassed in this build so QA can verify the full app.'
          : 'Unlock AI credits, premium coaching, deeper memory, and advanced tools.',
      plans: await getAvailablePlans(),
      isUnlocked: paywallTestingMode || _subscriptionState.isActive,
    );
  }

  @override
  Future<Entitlement> checkEntitlement({String? featureId}) async {
    if (paywallTestingMode) {
      return Entitlement(
        featureId: featureId ?? 'premium',
        isEntitled: true,
        source: 'testing_mode',
      );
    }
    return Entitlement(
      featureId: featureId ?? 'premium',
      isEntitled: _subscriptionState.isActive,
      source: _subscriptionState.source,
      expiresAt: _subscriptionState.renewalDate,
    );
  }

  @override
  Future<SubscriptionState> startSubscription(String planId) async {
    if (paywallTestingMode) {
      Logger.log('Paywall', 'Simulated purchase success for $planId.');
    }
    _subscriptionState = SubscriptionState(
      isActive: true,
      status: paywallTestingMode ? 'unlocked_for_testing' : 'active',
      source: paywallTestingMode ? 'testing_mode' : 'mock_service',
      planId: planId,
      renewalDate: DateTime.now().add(const Duration(days: 30)),
      isTesting: paywallTestingMode,
    );
    return _subscriptionState;
  }

  @override
  Future<SubscriptionState> cancelSubscription() async {
    if (paywallTestingMode) {
      Logger.log('Paywall', 'Simulated subscription cancellation.');
    }
    _subscriptionState = SubscriptionState(
      isActive: false,
      status: paywallTestingMode ? 'unlocked_for_testing' : 'cancelled',
      source: paywallTestingMode ? 'testing_mode' : 'mock_service',
      planId: _subscriptionState.planId,
      renewalDate: _subscriptionState.renewalDate,
      isTesting: paywallTestingMode,
    );
    return _subscriptionState;
  }

  @override
  Future<SubscriptionState> restorePurchases() async {
    if (paywallTestingMode) {
      Logger.log('Paywall', 'Simulated restore purchases success.');
      _subscriptionState = SubscriptionState(
        isActive: true,
        status: 'unlocked_for_testing',
        source: 'testing_mode',
        planId: _subscriptionState.planId ?? 'annual',
        renewalDate: DateTime.now().add(const Duration(days: 30)),
        isTesting: true,
      );
      return _subscriptionState;
    }
    return _subscriptionState;
  }

  @override
  Future<SubscriptionState> getUserSubscriptionState() async {
    if (paywallTestingMode && !_subscriptionState.isActive) {
      _subscriptionState = SubscriptionState(
        isActive: true,
        status: 'unlocked_for_testing',
        source: 'testing_mode',
        planId: _subscriptionState.planId ?? 'annual',
        renewalDate: DateTime.now().add(const Duration(days: 30)),
        isTesting: true,
      );
    }
    return _subscriptionState;
  }
}
