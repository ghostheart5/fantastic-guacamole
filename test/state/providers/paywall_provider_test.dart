import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paywallConfigProvider builds testing title from subscription state', () async {
    final _FakePaywallRepository repository = _FakePaywallRepository(
      subscription: const SubscriptionState(
        isActive: true,
        status: 'unlocked_for_testing',
        source: 'testing_mode',
        isTesting: true,
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [paywallRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final config = await container.read(paywallConfigProvider.future);

    expect(config.title, 'Unlocked for testing');
    expect(config.isUnlocked, isTrue);
    expect(config.plans, hasLength(2));
  });

  test('paywallActions forwards start and restore to repository', () async {
    final _FakePaywallRepository repository = _FakePaywallRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [paywallRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final actions = container.read(paywallActionsProvider);
    final started = await actions.startSubscription('monthly');
    final restored = await actions.restorePurchases();

    expect(started.planId, 'monthly');
    expect(repository.lastStartedPlanId, 'monthly');
    expect(restored.status, 'restored');
  });

  test('paywallPromptProvider stores and clears prompt state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(paywallPromptProvider.notifier)
        .set(
          const PaywallPrompt(
            title: 'Need premium',
            message: 'Unlock to continue',
            trigger: 'ai_limit',
          ),
        );
    expect(container.read(paywallPromptProvider)?.trigger, 'ai_limit');

    container.read(paywallPromptProvider.notifier).set(null);
    expect(container.read(paywallPromptProvider), isNull);
  });

  test('paywallEnabledProvider follows app access state', () {
    final ProviderContainer enabledContainer = ProviderContainer(
      overrides: [
        appAccessProvider.overrideWith(
          (Ref ref) => const AppAccessState(
            hasPremiumAccess: false,
            hasTesterFullAccess: false,
            paywallDisabled: false,
          ),
        ),
      ],
    );
    addTearDown(enabledContainer.dispose);

    final ProviderContainer disabledContainer = ProviderContainer(
      overrides: [
        appAccessProvider.overrideWith(
          (Ref ref) => const AppAccessState(
            hasPremiumAccess: true,
            hasTesterFullAccess: true,
            paywallDisabled: true,
          ),
        ),
      ],
    );
    addTearDown(disabledContainer.dispose);

    expect(enabledContainer.read(paywallEnabledProvider), isTrue);
    expect(disabledContainer.read(paywallEnabledProvider), isFalse);
  });
}

class _FakePaywallRepository implements IPaywallRepository {
  _FakePaywallRepository({SubscriptionState? subscription})
    : _subscription =
          subscription ??
          const SubscriptionState(isActive: false, status: 'locked', source: 'test');

  SubscriptionState _subscription;
  String? lastStartedPlanId;

  @override
  Future<SubscriptionState> cancelSubscription() async {
    _subscription = SubscriptionState(
      isActive: false,
      status: 'cancelled',
      source: _subscription.source,
      planId: _subscription.planId,
    );
    return _subscription;
  }

  @override
  Future<Entitlement> checkEntitlement({String? featureId}) async {
    return Entitlement(
      featureId: featureId ?? 'premium',
      isEntitled: _subscription.isActive,
      source: _subscription.source,
    );
  }

  @override
  Future<List<PaywallPlan>> getAvailablePlans() async {
    return const <PaywallPlan>[
      PaywallPlan(id: 'monthly', title: 'Monthly', priceLabel: '499', description: 'Monthly plan'),
      PaywallPlan(id: 'annual', title: 'Annual', priceLabel: '4999', description: 'Annual plan'),
    ];
  }

  @override
  Future<PaywallEntity> getPaywallConfig() async {
    return PaywallEntity(
      featureId: 'premium',
      title: 'Test paywall',
      body: 'Test body',
      plans: await getAvailablePlans(),
      isUnlocked: _subscription.isActive,
    );
  }

  @override
  Future<SubscriptionState> getUserSubscriptionState() async => _subscription;

  @override
  Future<SubscriptionState> restorePurchases() async {
    _subscription = SubscriptionState(
      isActive: true,
      status: 'restored',
      source: _subscription.source,
      planId: _subscription.planId ?? 'annual',
    );
    return _subscription;
  }

  @override
  Future<SubscriptionState> startSubscription(String planId) async {
    lastStartedPlanId = planId;
    _subscription = SubscriptionState(
      isActive: true,
      status: 'active',
      source: _subscription.source,
      planId: planId,
    );
    return _subscription;
  }
}
