import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

class PaywallRepository implements IPaywallRepository {
  PaywallRepository({bool? testingModeOverride, bool? aiProxyConfiguredOverride})
    : _testingMode = testingModeOverride ?? paywallTestingMode,
      _aiProxyConfigured = aiProxyConfiguredOverride ?? Env.isAiProxyConfigured {
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
  final bool _aiProxyConfigured;

  List<PaywallPlan> _buildPlans() {
    final String creditLabel = _aiProxyConfigured ? 'AI credits' : 'smart guidance credits';
    final String coachingLabel = _aiProxyConfigured ? 'AI coaching' : 'smart coaching';
    final String responseLabel = _aiProxyConfigured
        ? 'Priority AI responses'
        : 'Priority smart suggestions';

    return <PaywallPlan>[
      PaywallPlan(
        id: 'monthly',
        title: 'Premium Monthly',
        priceLabel: 'from \$9.99 / month',
        description: 'Best for active users who want full $coachingLabel and recurring credits.',
        aiCreditsIncluded: 300,
        freeTrialDays: 7,
        benefits: <String>[
          '7-day free trial for eligible new subscribers',
          '300 $creditLabel every month',
          responseLabel,
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
        freeTrialDays: 7,
        benefits: <String>[
          '7-day free trial for eligible new subscribers',
          '360 $creditLabel every month',
          'Yearly billing discount',
          'Unlimited access to premium tools',
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
    final bool aiMode = _aiProxyConfigured;
    return PaywallEntity(
      featureId: 'premium',
      title: _testingMode ? 'Unlocked for testing' : 'Billing unavailable',
      body: _testingMode
          ? 'Premium gates are bypassed in this build so QA can verify the full app.'
          : (aiMode
                ? 'Purchases are currently supported through Google Play on Android.'
                : 'Purchases are currently supported through Google Play on Android for Smart Coaching.'),
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
