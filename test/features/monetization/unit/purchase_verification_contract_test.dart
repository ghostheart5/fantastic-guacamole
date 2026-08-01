import 'package:fantastic_guacamole/features/monetization/data/services/purchase_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Purchase verification contracts', () {
    test('request validation enforces required fields', () {
      const PurchaseVerificationRequest valid = PurchaseVerificationRequest(
        productId: 'chronospark_credits_100',
        purchaseToken: 'token',
        purchaseType: 'inapp',
      );
      const PurchaseVerificationRequest invalid = PurchaseVerificationRequest(
        productId: '',
        purchaseToken: 'token',
        purchaseType: 'weird',
      );

      expect(valid.isValid, isTrue);
      expect(invalid.isValid, isFalse);
    });

    test('result parser maps typed payload', () {
      final PurchaseVerificationResult result = PurchaseVerificationResult.fromJson(
        <String, dynamic>{
          'valid': true,
          'productId': 'chronospark_premium_monthly',
          'planId': 'premium_monthly',
          'creditsGranted': 0,
          'orderId': 'order-1',
          'expiryTimeMs': 123,
        },
      );

      expect(result.valid, isTrue);
      expect(result.productId, 'chronospark_premium_monthly');
      expect(result.planId, 'premium_monthly');
      expect(result.errorCode, isNull);
    });

    test('mode resolver keeps release as production', () {
      final PurchaseVerificationMode mode = resolvePurchaseVerificationModeFromFlags(
        isReleaseMode: true,
        isProduction: false,
        isPaywallDisabled: true,
      );
      expect(mode, PurchaseVerificationMode.production);
    });
  });
}
