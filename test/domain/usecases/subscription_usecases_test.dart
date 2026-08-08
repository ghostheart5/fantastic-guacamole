import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/check_entitlement.dart';
import 'package:fantastic_guacamole/domain/usecases/start_subscription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartSubscription validates the plan id', () {
    late _FakePaywallRepository repository;

    setUp(() {
      repository = _FakePaywallRepository(
        plans: const <PaywallPlan>[
          PaywallPlan(
            id: 'premium_monthly',
            title: 'Monthly',
            priceLabel: r'$5',
            description: 'Billed monthly',
          ),
          PaywallPlan(
            id: 'premium_yearly',
            title: 'Yearly',
            priceLabel: r'$50',
            description: 'Billed yearly',
          ),
        ],
      );
    });

    test('starts a subscription for a known plan', () async {
      final SubscriptionState state = await StartSubscription(
        repository,
      ).call('premium_monthly');

      expect(state.isActive, isTrue);
      expect(repository.startedPlanIds, <String>['premium_monthly']);
    });

    test('rejects an unknown plan id before reaching billing', () async {
      await expectLater(
        () => StartSubscription(repository).call('not_a_real_plan'),
        throwsArgumentError,
      );

      expect(
        repository.startedPlanIds,
        isEmpty,
        reason: 'an unknown plan must never reach the billing layer',
      );
    });

    test('rejects a blank plan id without querying plans', () async {
      await expectLater(
        () => StartSubscription(repository).call('  '),
        throwsArgumentError,
      );

      expect(repository.startedPlanIds, isEmpty);
      expect(repository.getAvailablePlansCallCount, 0);
    });
  });

  group('CheckEntitlement', () {
    test('returns a granted entitlement', () async {
      final _FakePaywallRepository repository = _FakePaywallRepository(
        entitled: true,
      );

      final Entitlement entitlement = await CheckEntitlement(
        repository,
      ).call(featureId: 'si_console');

      expect(entitlement.featureId, 'si_console');
      expect(entitlement.isEntitled, isTrue);
      expect(repository.lastFeatureId, 'si_console');
    });

    test('returns a denied entitlement without treating it as an error', () async {
      final _FakePaywallRepository repository = _FakePaywallRepository(
        entitled: false,
      );

      final Entitlement entitlement = await CheckEntitlement(
        repository,
      ).call(featureId: 'si_console');

      expect(entitlement.isEntitled, isFalse);
      expect(entitlement.featureId, 'si_console');
    });

    test('rejects a blank feature id', () async {
      final _FakePaywallRepository repository = _FakePaywallRepository();

      await expectLater(
        () => CheckEntitlement(repository).call(featureId: '  '),
        throwsArgumentError,
      );

      expect(repository.lastFeatureId, isNull);
    });
  });
}

class _FakePaywallRepository implements IPaywallRepository {
  _FakePaywallRepository({
    this.plans = const <PaywallPlan>[],
    this.entitled = true,
  });

  final List<PaywallPlan> plans;
  final bool entitled;

  final List<String> startedPlanIds = <String>[];
  String? lastFeatureId;
  int getAvailablePlansCallCount = 0;

  @override
  Future<Entitlement> checkEntitlement({String? featureId}) async {
    lastFeatureId = featureId;
    return Entitlement(
      featureId: featureId ?? 'premium',
      isEntitled: entitled,
      source: 'test',
    );
  }

  @override
  Future<List<PaywallPlan>> getAvailablePlans() async {
    getAvailablePlansCallCount++;
    return plans;
  }

  @override
  Future<PaywallEntity> getPaywallConfig() async => PaywallEntity(
    featureId: 'premium',
    title: 'Premium',
    body: 'Unlock premium',
    plans: plans,
    isUnlocked: false,
  );

  @override
  Future<SubscriptionState> getUserSubscriptionState() async =>
      const SubscriptionState(isActive: false, status: 'inactive', source: 'test');

  @override
  Future<SubscriptionState> startSubscription(String planId) async {
    startedPlanIds.add(planId);
    return SubscriptionState(
      isActive: true,
      status: 'active',
      source: 'test',
      planId: planId,
    );
  }

  @override
  Future<SubscriptionState> cancelSubscription() async =>
      const SubscriptionState(isActive: false, status: 'canceled', source: 'test');

  @override
  Future<SubscriptionState> restorePurchases() async =>
      const SubscriptionState(isActive: false, status: 'inactive', source: 'test');
}
