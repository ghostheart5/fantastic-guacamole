import 'package:fantastic_guacamole/features/monetization/data/models/premium_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PremiumEntitlement.tier', () {
    test('returns free when not premium', () {
      const PremiumEntitlement entitlement = PremiumEntitlement(
        isPremium: false,
        isActive: true,
        planId: 'premium_monthly',
        source: 'test',
      );

      expect(entitlement.tier, EntitlementTier.free);
    });

    test('returns free when inactive', () {
      const PremiumEntitlement entitlement = PremiumEntitlement(
        isPremium: true,
        isActive: false,
        planId: 'lifetime',
        source: 'test',
      );

      expect(entitlement.tier, EntitlementTier.free);
    });

    test('returns premium for active premium plan', () {
      const PremiumEntitlement entitlement = PremiumEntitlement(
        isPremium: true,
        isActive: true,
        planId: 'premium_monthly',
        source: 'test',
      );

      expect(entitlement.tier, EntitlementTier.premium);
    });

    test('returns ultimate for lifetime/ultimate plans', () {
      const PremiumEntitlement lifetimeEntitlement = PremiumEntitlement(
        isPremium: true,
        isActive: true,
        planId: 'lifetime',
        source: 'test',
      );
      const PremiumEntitlement ultimateEntitlement = PremiumEntitlement(
        isPremium: true,
        isActive: true,
        planId: 'ultimate',
        source: 'test',
      );

      expect(lifetimeEntitlement.tier, EntitlementTier.ultimate);
      expect(ultimateEntitlement.tier, EntitlementTier.ultimate);
    });
  });
}
