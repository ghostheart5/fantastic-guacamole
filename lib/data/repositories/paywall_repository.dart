import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

class PaywallRepository implements IPaywallRepository {
  PaywallRepository({bool? testingModeOverride})
    : _testingMode = testingModeOverride ?? paywallTestingMode {
    _subscriptionState = SubscriptionState(
      isActive: _testingMode,
      status: _testingMode ? 'unlocked_for_testing' : 'locked',
      source: _testingMode ? 'testing_mode' : 'platform_unavailable',
      isTesting: _testingMode,
    );
  }

  static SubscriptionState _subscriptionState = const SubscriptionState(
    isActive: false,
    status: 'locked',
    source: 'platform_unavailable',
  );
  final bool _testingMode;

  List<PaywallPlan> _buildPlans() {
    return const <PaywallPlan>[
      PaywallPlan(
        id: 'monthly',
        title: 'Monthly plan',
        priceLabel: 'Price unavailable',
        description: 'Monthly subscription billed through Google Play.',
        aiCreditsIncluded: 300,
        freeTrialDays: 0,
        benefits: <String>[
          'Increases external-assistant credit allowance to 300 credits per month',
        ],
      ),
      PaywallPlan(
        id: 'annual',
        title: 'Annual plan',
        priceLabel: 'Price unavailable',
        description: 'Annual subscription billed through Google Play.',
        aiCreditsIncluded: 360,
        freeTrialDays: 0,
        benefits: <String>[
          'Increases external-assistant credit allowance to 360 credits per month',
        ],
      ),
    ];
  }

  @override
  Future<List<PaywallPlan>> getAvailablePlans() async {
    final List<PaywallPlan> plans = _buildPlans();
    return plans
        .map(
          (PaywallPlan plan) => PaywallPlan(
            id: plan.id,
            title: plan.title,
            priceLabel: plan.priceLabel,
            description: plan.description,
            aiCreditsIncluded: plan.aiCreditsIncluded,
            freeTrialDays: plan.freeTrialDays,
            benefits: plan.benefits,
            isAvailable: _testingMode,
            isFeatured: plan.isFeatured,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<PaywallEntity> getPaywallConfig() async {
    return PaywallEntity(
      featureId: 'premium',
      title: _testingMode ? 'Unlocked for testing' : 'Billing unavailable',
      body: _testingMode
          ? 'Subscription checks are bypassed in this testing mode.'
          : 'Purchases are unavailable on this platform.',
      plans: await getAvailablePlans(),
      isUnlocked: _testingMode || _subscriptionState.isActive,
    );
  }

  @override
  Future<Entitlement> checkEntitlement({String? featureId}) async {
    if (_testingMode) {
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
    if (!_testingMode) {
      throw StateError('Purchases are unavailable on this platform.');
    }
    Logger.log('Paywall', 'Simulated purchase success for $planId.');
    _subscriptionState = SubscriptionState(
      isActive: true,
      status: _testingMode ? 'unlocked_for_testing' : 'active',
      source: _testingMode ? 'testing_mode' : 'platform_unavailable',
      planId: planId,
      renewalDate: DateTime.now().add(const Duration(days: 30)),
      isTesting: _testingMode,
    );
    return _subscriptionState;
  }

  @override
  Future<SubscriptionState> cancelSubscription() async {
    if (!_testingMode) {
      return _subscriptionState;
    }
    Logger.log('Paywall', 'Simulated subscription cancellation.');
    _subscriptionState = SubscriptionState(
      isActive: false,
      status: _testingMode ? 'unlocked_for_testing' : 'cancelled',
      source: _testingMode ? 'testing_mode' : 'platform_unavailable',
      planId: _subscriptionState.planId,
      renewalDate: _subscriptionState.renewalDate,
      isTesting: _testingMode,
    );
    return _subscriptionState;
  }

  @override
  Future<SubscriptionState> restorePurchases() async {
    if (_testingMode) {
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
    if (_testingMode && !_subscriptionState.isActive) {
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

class ContainedPaywallRepository implements IPaywallRepository {
  const ContainedPaywallRepository();

  static const SubscriptionState _state = SubscriptionState(
    isActive: false,
    status: 'launch_contained',
    source: 'launch_containment',
  );

  @override
  Future<List<PaywallPlan>> getAvailablePlans() async => const <PaywallPlan>[];

  @override
  Future<PaywallEntity> getPaywallConfig() async => const PaywallEntity(
    featureId: 'premium',
    title: 'Plans unavailable',
    body:
        'Subscriptions are disabled while launch-readiness work is completed.',
    plans: <PaywallPlan>[],
    isUnlocked: false,
  );

  @override
  Future<Entitlement> checkEntitlement({String? featureId}) async =>
      Entitlement(
        featureId: featureId ?? 'premium',
        isEntitled: false,
        source: 'launch_containment',
      );

  @override
  Future<SubscriptionState> getUserSubscriptionState() async => _state;

  @override
  Future<SubscriptionState> startSubscription(String planId) async {
    throw const LaunchContainedException('Subscriptions');
  }

  @override
  Future<SubscriptionState> restorePurchases() async {
    throw const LaunchContainedException('Purchase restoration');
  }

  @override
  Future<SubscriptionState> cancelSubscription() async => _state;
}
