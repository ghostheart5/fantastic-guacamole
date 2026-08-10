import 'package:fantastic_guacamole/features/monetization/integration/monetization_actions_compat.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_compat_providers.dart';
import 'package:fantastic_guacamole/state/providers/app_integration_actions_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/services/app_integration_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMonetizationActionsCompat implements MonetizationActionsCompat {
  const _FakeMonetizationActionsCompat();

  @override
  MonetizationStackType get stackType => MonetizationStackType.legacy;

  @override
  Future<List<MonetizationCreditOption>> fetchCreditOptions() async {
    return const <MonetizationCreditOption>[
      MonetizationCreditOption(
        id: 'credits_100',
        productId: 'chronospark_credits_100',
        name: '100 Credits',
        totalCredits: 100,
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<MonetizationPlanOption>> fetchPlanOptions() async {
    return const <MonetizationPlanOption>[
      MonetizationPlanOption(
        id: 'premium_monthly',
        productId: 'chronospark_premium_monthly',
        name: 'Premium Monthly',
        isActive: true,
      ),
    ];
  }

  @override
  Future<MonetizationStatusSnapshot> fetchStatus() async {
    return const MonetizationStatusSnapshot(
      planId: 'premium_monthly',
      isPremium: true,
      isActive: true,
      walletBalance: 250,
      stackType: MonetizationStackType.legacy,
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> purchaseCreditsByProductId(
    String productId,
  ) async {
    return MonetizationPurchaseOutcome(
      success: true,
      productId: productId,
      message: 'credits',
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> purchaseSubscriptionByProductId(
    String productId,
  ) async {
    return MonetizationPurchaseOutcome(
      success: true,
      productId: productId,
      message: 'subscription',
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> restorePurchases() async {
    return const MonetizationPurchaseOutcome(
      success: true,
      productId: '__restore__',
      message: 'restored',
    );
  }
}

void main() {
  group('appIntegrationActionsProvider', () {
    test('resolves an AppIntegrationActions instance', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          syncServiceProvider.overrideWithValue(null),
          monetizationActionsCompatProvider.overrideWithValue(
            const _FakeMonetizationActionsCompat(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final actions = container.read(appIntegrationActionsProvider);
      expect(actions, isNotNull);
      expect(actions.monetizationStackType, MonetizationStackType.legacy);
    });

    test(
      'sync operations fail safely when sync service is unavailable',
      () async {
        final ProviderContainer container = ProviderContainer(
          overrides: [
            syncServiceProvider.overrideWithValue(null),
            monetizationActionsCompatProvider.overrideWithValue(
              const _FakeMonetizationActionsCompat(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final actions = container.read(appIntegrationActionsProvider);
        final bool syncToCloud = await actions.syncToCloud();
        final bool syncDelta = await actions.syncDelta();
        final bool restore = await actions.restoreFromCloud();

        expect(syncToCloud, isFalse);
        expect(syncDelta, isFalse);
        expect(restore, isFalse);
      },
    );

    test(
      'fetches monetization snapshot from the shared compat layer',
      () async {
        final ProviderContainer container = ProviderContainer(
          overrides: [
            syncServiceProvider.overrideWithValue(null),
            monetizationActionsCompatProvider.overrideWithValue(
              const _FakeMonetizationActionsCompat(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final actions = container.read(appIntegrationActionsProvider);
        final MonetizationStatusSnapshot snapshot = await actions
            .fetchMonetizationSnapshot();
        final List<MonetizationPlanOption> plans = await actions
            .fetchMonetizationPlanOptions();
        final List<MonetizationCreditOption> credits = await actions
            .fetchMonetizationCreditOptions();

        expect(snapshot.stackType, MonetizationStackType.legacy);
        expect(snapshot.isPremium, isTrue);
        expect(plans, hasLength(1));
        expect(credits, hasLength(1));
      },
    );

    test(
      'fetches a safe integration snapshot without requiring sync',
      () async {
        final ProviderContainer container = ProviderContainer(
          overrides: [
            syncServiceProvider.overrideWithValue(null),
            monetizationActionsCompatProvider.overrideWithValue(
              const _FakeMonetizationActionsCompat(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final actions = container.read(appIntegrationActionsProvider);
        final AppIntegrationSnapshot snapshot = await actions
            .fetchIntegrationSnapshot();

        expect(snapshot.currentUserId, isNull);
        expect(snapshot.offlineQueueCount, 0);
        expect(snapshot.syncErrorMessage, isNull);
        expect(
          snapshot.monetizationStatus.stackType,
          MonetizationStackType.legacy,
        );
        expect(snapshot.supabaseHealth.configured, isFalse);
      },
    );
  });
}
