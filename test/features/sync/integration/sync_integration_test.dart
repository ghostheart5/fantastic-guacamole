import 'package:fantastic_guacamole/features/monetization/integration/monetization_actions_compat.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_compat_providers.dart';
import 'package:fantastic_guacamole/state/providers/app_integration_actions_provider.dart';
import 'package:fantastic_guacamole/state/services/app_integration_actions.dart';
import 'package:fantastic_guacamole/state/providers/supabase_backend_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  group('sync integration flow', () {
    test('sync error notifier state is reflected in app integration snapshot', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          syncServiceProvider.overrideWithValue(null),
          monetizationActionsCompatProvider.overrideWithValue(
            const _FakeMonetizationActionsCompat(),
          ),
          offlineQueueCountProvider.overrideWith((Ref ref) async => 7),
          supabaseBackendHealthProvider.overrideWith(
            (Ref ref) async => const SupabaseBackendHealth(
              configured: false,
              initialized: false,
              authenticated: false,
              databaseReachable: false,
              storageReachable: false,
              realtimeConfigured: false,
              badge: SupabaseHealthBadge.connectivityIssue,
              message: 'not configured',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(syncErrorMessageProvider.notifier)
          .set('Cloud sync failed. retry queued.');

        await container.read(offlineQueueCountProvider.future);

      final AppIntegrationSnapshot snapshot = await container
          .read(appIntegrationActionsProvider)
          .fetchIntegrationSnapshot();

      expect(snapshot.syncErrorMessage, 'Cloud sync failed. retry queued.');
      expect(snapshot.offlineQueueCount, 7);
      expect(snapshot.monetizationStatus.stackType, MonetizationStackType.legacy);
      expect(snapshot.supabaseHealth.configured, isFalse);
    });

    test('sync operations fail safely when sync service is unavailable', () async {
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
      expect(await actions.syncToCloud(), isFalse);
      expect(await actions.syncDelta(), isFalse);
      expect(await actions.restoreFromCloud(), isFalse);
    });
  });
}

class _FakeMonetizationActionsCompat implements MonetizationActionsCompat {
  const _FakeMonetizationActionsCompat();

  @override
  MonetizationStackType get stackType => MonetizationStackType.legacy;

  @override
  Future<List<MonetizationCreditOption>> fetchCreditOptions() async {
    return const <MonetizationCreditOption>[];
  }

  @override
  Future<List<MonetizationPlanOption>> fetchPlanOptions() async {
    return const <MonetizationPlanOption>[];
  }

  @override
  Future<MonetizationStatusSnapshot> fetchStatus() async {
    return const MonetizationStatusSnapshot(
      planId: 'free',
      isPremium: false,
      isActive: true,
      walletBalance: 0,
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
      message: 'ok',
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> purchaseSubscriptionByProductId(
    String productId,
  ) async {
    return MonetizationPurchaseOutcome(
      success: true,
      productId: productId,
      message: 'ok',
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> restorePurchases() async {
    return const MonetizationPurchaseOutcome(
      success: true,
      productId: '__restore__',
      message: 'ok',
    );
  }
}
