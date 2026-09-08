import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subscription_repository.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'enabled internal credit policy retains approved plan allowances',
    () async {
      final container = ProviderContainer(
        overrides: [
          internalBillingTestEnabledProvider.overrideWithValue(true),
          internalCreditTestEnabledProvider.overrideWithValue(true),
          appPaywallRepositoryProvider.overrideWithValue(
            _FakePaywallRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final config = await container.read(paywallConfigProvider.future);
      expect(config.plans.map((p) => p.aiCreditsIncluded), [300, 300]);
    },
  );

  test(
    'credit purchase outcomes cannot be replaced by subscription authority',
    () async {
      for (final status in [
        'credits_added',
        'verification_failed',
        'purchase_pending',
      ]) {
        final repository = _CreditOutcomeRepository(
          SubscriptionState(
            isActive: false,
            status: status,
            source: 'google_play',
          ),
        );
        final container = ProviderContainer(
          overrides: [
            internalBillingTestEnabledProvider.overrideWithValue(true),
            appPaywallRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        final result = await container
            .read(paywallActionsProvider)
            .startSubscription('credits_100');
        expect(result.status, status);
        expect(result.isActive, isFalse);
        expect(repository.refreshCalls, 0);
      }
    },
  );
  test(
    'paywall and plans expire together without restore or navigation',
    () async {
      final repository = _FakePaywallRepository(
        subscription: SubscriptionState(
          isActive: true,
          status: 'canceled',
          source: 'supabase_authority',
          renewalDate: DateTime.now().add(const Duration(milliseconds: 400)),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          internalBillingTestEnabledProvider.overrideWithValue(true),
          appPaywallRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.listen(paywallConfigProvider, (_, _) {});
      expect(
        (await container.read(paywallConfigProvider.future)).isUnlocked,
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(
        (await container.read(paywallSubscriptionProvider.future)).isActive,
        isFalse,
      );
      expect(
        (await container.read(paywallConfigProvider.future)).isUnlocked,
        isFalse,
      );
    },
  );

  test('plans follow refreshed subscription after pause and resume', () async {
    final repository = _FakePaywallRepository();
    final container = ProviderContainer(
      overrides: [
        internalBillingTestEnabledProvider.overrideWithValue(true),
        appPaywallRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(paywallConfigProvider, (_, _) {});
    for (final active in [false, true, false, true]) {
      repository._subscription = SubscriptionState(
        isActive: active,
        status: active ? 'active' : 'paused',
        source: 'supabase_authority',
      );
      container.invalidate(paywallSubscriptionProvider);
      expect(
        (await container.read(paywallConfigProvider.future)).isUnlocked,
        active,
      );
    }
  });

  test(
    'license testing uses repository authority without advertising AI credits',
    () async {
      final repository = _FakePaywallRepository();
      final container = ProviderContainer(
        overrides: [
          internalBillingTestEnabledProvider.overrideWithValue(true),
          appPaywallRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final config = await container.read(paywallConfigProvider.future);
      expect(config.title, 'Google Play billing test');
      expect(config.body, contains('AI and credit spending are unavailable'));
      expect(config.isUnlocked, isFalse);
      expect(config.plans.every((p) => p.aiCreditsIncluded == 0), isTrue);
      await container.read(paywallActionsProvider).startSubscription('monthly');
      expect(repository.lastStartedPlanId, 'monthly');
      expect(repository.refreshCalls, 1);
    },
  );

  test(
    'paywall use cases follow repository replacement after account change',
    () async {
      final first = _FakePaywallRepository();
      final next = _FakePaywallRepository();
      final container = ProviderContainer(
        overrides: [
          internalBillingTestEnabledProvider.overrideWithValue(true),
          appPaywallRepositoryProvider.overrideWithValue(first),
        ],
      );
      addTearDown(container.dispose);
      container.read(startSubscriptionUseCaseProvider);
      container.updateOverrides([
        internalBillingTestEnabledProvider.overrideWithValue(true),
        appPaywallRepositoryProvider.overrideWithValue(next),
      ]);
      await container.read(paywallActionsProvider).startSubscription('monthly');
      expect(first.lastStartedPlanId, isNull);
      expect(next.lastStartedPlanId, 'monthly');
    },
  );

  test(
    'paywallConfigProvider ignores repository state during containment',
    () async {
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

      expect(config.title, 'Plans unavailable');
      expect(config.isUnlocked, isFalse);
      expect(config.plans, isEmpty);
    },
  );

  test('paywallActions block start and restore during containment', () async {
    final _FakePaywallRepository repository = _FakePaywallRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [paywallRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final actions = container.read(paywallActionsProvider);
    await expectLater(
      actions.startSubscription('monthly'),
      throwsA(isA<Exception>()),
    );
    await expectLater(actions.restorePurchases(), throwsA(isA<Exception>()));

    expect(repository.lastStartedPlanId, isNull);
    expect(repository.refreshCalls, 0);
  });

  test('explicit inactive billing outcomes bypass authority replacement', () {
    for (final String status in <String>[
      'purchase_pending',
      'purchase_canceled',
      'nothing_to_restore',
      'restore_error',
    ]) {
      expect(
        requiresPaywallAuthorityRefresh(
          SubscriptionState(
            isActive: false,
            status: status,
            source: 'google_play',
          ),
        ),
        isFalse,
        reason: '$status must reach the page unchanged.',
      );
    }

    expect(
      requiresPaywallAuthorityRefresh(
        const SubscriptionState(
          isActive: false,
          status: 'verification_failed',
          source: 'google_play',
        ),
      ),
      isTrue,
      reason:
          'Ambiguous verification failures need an authoritative server read.',
    );

    expect(
      requiresPaywallAuthorityRefresh(
        const SubscriptionState(
          isActive: true,
          status: 'active',
          source: 'google_play',
        ),
      ),
      isTrue,
    );
    expect(
      requiresPaywallAuthorityRefresh(
        const SubscriptionState(
          isActive: false,
          status: 'locked',
          source: 'google_play',
        ),
      ),
      isTrue,
    );
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

  test('paywallEnabledProvider remains false during containment', () {
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

    expect(enabledContainer.read(paywallEnabledProvider), isFalse);
    expect(disabledContainer.read(paywallEnabledProvider), isFalse);
  });
}

class _FakePaywallRepository
    implements IPaywallRepository, ISubscriptionAuthorityRefresher {
  _FakePaywallRepository({SubscriptionState? subscription})
    : _subscription =
          subscription ??
          const SubscriptionState(
            isActive: false,
            status: 'locked',
            source: 'test',
          );

  SubscriptionState _subscription;
  String? lastStartedPlanId;
  int refreshCalls = 0;

  @override
  Future<SubscriptionState> refreshSubscriptionState({
    bool force = false,
  }) async {
    refreshCalls += 1;
    return _subscription;
  }

  @override
  bool get shouldRestoreLegacySubscription => false;

  @override
  DateTime? get legacyRestoreNextRetryAt => null;

  @override
  Future<SubscriptionState?> restoreLegacySubscription() async => null;

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
      PaywallPlan(
        id: 'monthly',
        title: 'Monthly',
        priceLabel: '499',
        description: 'Monthly plan',
        aiCreditsIncluded: 300,
      ),
      PaywallPlan(
        id: 'annual',
        title: 'Annual',
        priceLabel: '4999',
        description: 'Annual plan',
        aiCreditsIncluded: 300,
      ),
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

class _CreditOutcomeRepository extends _FakePaywallRepository {
  _CreditOutcomeRepository(this.outcome);
  final SubscriptionState outcome;
  @override
  Future<List<PaywallPlan>> getAvailablePlans() async => [
    ...await super.getAvailablePlans(),
    const PaywallPlan(
      id: 'credits_100',
      title: '100 credits',
      priceLabel: '\$2.99',
      description: 'Pack',
      aiCreditsIncluded: 100,
    ),
  ];
  @override
  Future<SubscriptionState> startSubscription(String planId) async => outcome;
}
