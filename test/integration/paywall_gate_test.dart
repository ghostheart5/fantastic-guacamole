import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/paywall_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/services/credit_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'launch containment blocks credit spending and purchase actions',
    () async {
      final _MemorySharedPrefsStore prefs = _MemorySharedPrefsStore();
      final CreditService credit = CreditService(prefs: prefs);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          sharedPrefsStoreProvider.overrideWithValue(prefs),
          creditServiceProvider.overrideWithValue(credit),
        ],
      );
      addTearDown(container.dispose);

      final AiCreditWallet exposedWallet = await container.read(
        aiCreditWalletProvider.future,
      );
      expect(LaunchContainment.paidCreditPlansEnabled, isFalse);
      expect(exposedWallet.balance, 0);
      expect(exposedWallet.tier, 'unavailable');

      final AiCreditWallet before = await credit.loadWallet(premium: false);
      final AiCreditSpendResult denied = await credit.spend(
        premium: false,
        amount: 1,
      );
      final AiCreditWallet after = await credit.loadWallet(premium: false);
      expect(denied.allowed, isFalse);
      expect(after.balance, before.balance);

      final config = await container.read(paywallConfigProvider.future);
      expect(config.title, 'Plans unavailable');
      expect(config.plans, isEmpty);
      expect(container.read(paywallEnabledProvider), isFalse);
      expect(
        container.read(paywallRepositoryProvider),
        isA<ContainedPaywallRepository>(),
      );

      final actions = container.read(paywallActionsProvider);
      await expectLater(
        actions.startSubscription('monthly'),
        throwsA(isA<LaunchContainedException>()),
      );
      await expectLater(
        actions.restorePurchases(),
        throwsA(isA<LaunchContainedException>()),
      );
    },
  );
}

class _MemorySharedPrefsStore implements SharedPrefsStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> init() async {}

  @override
  String? load(String key) {
    return _store[key];
  }

  @override
  Future<void> save(String key, String value) async {
    _store[key] = value;
  }
}
