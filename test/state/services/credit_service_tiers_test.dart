import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/services/credit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreditService subscription tiers', () {
    test('enforce credit limits for free and premium-like access', () async {
      final CreditService baseService = CreditService(prefs: _MemoryPrefsStore());
      final CreditService premiumService = CreditService(prefs: _MemoryPrefsStore());
      final CreditService ultimateService = CreditService(prefs: _MemoryPrefsStore());

      final baseWallet = await baseService.loadWallet(premium: false);
      final premiumWallet = await premiumService.loadWallet(premium: true);
      final ultimateLikeWallet = await ultimateService.loadWallet(premium: true);

      expect(baseWallet.tier, 'free');
      expect(baseWallet.allowance, 20);
      expect(premiumWallet.tier, 'premium');
      expect(premiumWallet.allowance, 300);
      expect(ultimateLikeWallet.tier, 'premium');
      expect(ultimateLikeWallet.allowance, 300);

      final baseDenied = await baseService.spend(premium: false, amount: 21);
      expect(baseDenied.allowed, isFalse);

      final premiumAllowed = await premiumService.spend(premium: true, amount: 250);
      expect(premiumAllowed.allowed, isTrue);

      const AppAccessState ultimateLike = AppAccessState(
        hasPremiumAccess: true,
        hasTesterFullAccess: true,
        paywallDisabled: false,
      );
      expect(ultimateLike.subscriptionStatusLabel, 'Unlocked for testing');
      expect(ultimateLike.paywallEnabled, isFalse);
    });
  });
}

class _MemoryPrefsStore implements SharedPrefsStore {
  final Map<String, String> _storage = <String, String>{};

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => _storage[key];

  @override
  Future<void> save(String key, String value) async {
    _storage[key] = value;
  }
}
