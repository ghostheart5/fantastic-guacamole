import 'package:fantastic_guacamole/features/monetization/data/services/purchase_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePurchaseVerificationModeFromFlags', () {
    test('always forces production in release mode', () {
      final PurchaseVerificationMode mode =
          resolvePurchaseVerificationModeFromFlags(
            isReleaseMode: true,
            isProduction: false,
            isPaywallDisabled: true,
          );

      expect(mode, PurchaseVerificationMode.production);
    });

    test('uses local test only for non-release non-production with paywall disabled', () {
      final PurchaseVerificationMode mode =
          resolvePurchaseVerificationModeFromFlags(
            isReleaseMode: false,
            isProduction: false,
            isPaywallDisabled: true,
          );

      expect(mode, PurchaseVerificationMode.localTest);
    });

    test('uses production when paywall is enabled', () {
      final PurchaseVerificationMode mode =
          resolvePurchaseVerificationModeFromFlags(
            isReleaseMode: false,
            isProduction: false,
            isPaywallDisabled: false,
          );

      expect(mode, PurchaseVerificationMode.production);
    });

    test('uses production when environment is production', () {
      final PurchaseVerificationMode mode =
          resolvePurchaseVerificationModeFromFlags(
            isReleaseMode: false,
            isProduction: true,
            isPaywallDisabled: true,
          );

      expect(mode, PurchaseVerificationMode.production);
    });
  });
}
