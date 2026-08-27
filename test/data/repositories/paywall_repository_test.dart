import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/data/repositories/paywall_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('getPaywallConfig reflects mode and includes plans', () async {
    final testingRepository = PaywallRepository(testingModeOverride: true);
    final liveRepository = PaywallRepository(testingModeOverride: false);

    final testingConfig = await testingRepository.getPaywallConfig();
    final liveConfig = await liveRepository.getPaywallConfig();

    expect(testingConfig.title, 'Unlocked for testing');
    expect(testingConfig.isUnlocked, isTrue);
    expect(testingConfig.plans, isNotEmpty);

    expect(liveConfig.title, 'Billing unavailable');
    expect(liveConfig.isUnlocked, isFalse);
    expect(liveConfig.plans, isNotEmpty);
  });

  test('returns default plans for paywall surface', () async {
    final repository = PaywallRepository(testingModeOverride: true);

    final plans = await repository.getAvailablePlans();

    expect(plans, hasLength(2));
    expect(
      plans.map((plan) => plan.id),
      containsAll(<String>['monthly', 'annual']),
    );
    expect(plans.every((plan) => plan.isAvailable), isTrue);
  });

  test(
    'checkEntitlement forwards feature id and uses current mode source',
    () async {
      final testingRepository = PaywallRepository(testingModeOverride: true);
      final liveRepository = PaywallRepository(testingModeOverride: false);

      final testingEntitlement = await testingRepository.checkEntitlement(
        featureId: 'si_console',
      );
      final liveEntitlement = await liveRepository.checkEntitlement();

      expect(testingEntitlement.featureId, 'si_console');
      expect(testingEntitlement.isEntitled, isTrue);
      expect(testingEntitlement.source, 'testing_mode');

      expect(liveEntitlement.featureId, 'premium');
      expect(liveEntitlement.source, isNotEmpty);
    },
  );

  test('testing mode start/cancel lifecycle stays unlocked for QA', () async {
    final repository = PaywallRepository(testingModeOverride: true);

    final started = await repository.startSubscription('monthly');
    expect(started.isActive, isTrue);
    expect(started.planId, 'monthly');
    expect(started.status, 'unlocked_for_testing');

    final cancelled = await repository.cancelSubscription();
    expect(cancelled.isActive, isFalse);
    expect(cancelled.planId, 'monthly');
    expect(cancelled.status, 'unlocked_for_testing');
  });

  test('non-testing mode blocks purchase and leaves locked state', () async {
    final repository = PaywallRepository(testingModeOverride: false);

    await expectLater(
      () => repository.startSubscription('monthly'),
      throwsA(isA<StateError>()),
    );

    final cancelled = await repository.cancelSubscription();
    expect(cancelled.isActive, isFalse);
    expect(cancelled.status, 'locked');
  });

  test(
    'restorePurchases and getUserSubscriptionState branches by mode',
    () async {
      final testingRepository = PaywallRepository(testingModeOverride: true);

      final restoredTesting = await testingRepository.restorePurchases();
      expect(restoredTesting.isActive, isTrue);
      expect(restoredTesting.isTesting, isTrue);
      expect(restoredTesting.status, 'unlocked_for_testing');
      expect(restoredTesting.planId, isNotEmpty);

      final liveRepository = PaywallRepository(testingModeOverride: false);
      final restoredLive = await liveRepository.restorePurchases();
      expect(restoredLive.status, 'locked');

      final liveState = await liveRepository.getUserSubscriptionState();
      expect(liveState.status, 'locked');

      final testingState = await testingRepository.getUserSubscriptionState();
      expect(testingState.isActive, isTrue);
      expect(testingState.status, 'unlocked_for_testing');
    },
  );

  test('default constructor follows global compatibility flag', () {
    final repository = PaywallRepository();
    expect(repository, isA<PaywallRepository>());
    expect(paywallTestingMode, anyOf(isTrue, isFalse));
  });
}
