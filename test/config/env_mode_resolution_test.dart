import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env mode resolution', () {
    test('every release build receives production security rules', () {
      expect(Env.resolveIsProduction('prod', isReleaseMode: true), isTrue);
      expect(Env.resolveIsProduction('prod', isReleaseMode: false), isFalse);
      expect(Env.resolveIsProduction('dev', isReleaseMode: true), isTrue);
    });

    test('mock mode is enabled only in non-production when explicitly enabled', () {
      expect(Env.resolveIsMockMode(isProduction: false, enableMockMode: true), isTrue);
      expect(Env.resolveIsMockMode(isProduction: false, enableMockMode: false), isFalse);
      expect(Env.resolveIsMockMode(isProduction: true, enableMockMode: true), isFalse);
    });

    test('paywall disabled follows dev/mock mode but never production', () {
      expect(
        Env.resolveIsPaywallDisabled(
          isProduction: false,
          enablePaywallDisabled: true,
          isMockMode: false,
        ),
        isTrue,
      );
      expect(
        Env.resolveIsPaywallDisabled(
          isProduction: false,
          enablePaywallDisabled: false,
          isMockMode: true,
        ),
        isTrue,
      );
      expect(
        Env.resolveIsPaywallDisabled(
          isProduction: true,
          enablePaywallDisabled: true,
          isMockMode: true,
        ),
        isFalse,
      );
    });

    test('mock login is opt-in in non-production and always blocked in production', () {
      expect(
        Env.resolveIsMockLoginEnabled(
          isProduction: false,
          isMockMode: false,
          enableMockLogin: false,
        ),
        isFalse,
      );
      expect(
        Env.resolveIsMockLoginEnabled(
          isProduction: false,
          isMockMode: false,
          enableMockLogin: true,
        ),
        isTrue,
      );
      expect(
        Env.resolveIsMockLoginEnabled(
          isProduction: false,
          isMockMode: true,
          enableMockLogin: false,
        ),
        isTrue,
      );
      expect(
        Env.resolveIsMockLoginEnabled(isProduction: true, isMockMode: false, enableMockLogin: true),
        isFalse,
      );
      expect(
        Env.resolveIsMockLoginEnabled(
          isProduction: true,
          isMockMode: false,
          enableMockLogin: false,
        ),
        isFalse,
      );
    });

    test('tester full access remains production-safe', () {
      expect(
        Env.resolveHasTesterFullAccess(isProduction: true, enableTesterFullAccess: false),
        isFalse,
      );
      expect(
        Env.resolveHasTesterFullAccess(isProduction: false, enableTesterFullAccess: false),
        isFalse,
      );
      expect(
        Env.resolveHasTesterFullAccess(isProduction: false, enableTesterFullAccess: true),
        isTrue,
      );
    });

    test('receipt verification endpoint derives from configuration safely', () {
      expect(
        Env.resolveReceiptVerifyEndpoint(
          'https://billing.chronospark.app/verify-receipt',
          supabaseUrl: 'https://ignored.example.supabase.co',
        ),
        'https://billing.chronospark.app/verify-receipt',
      );
      expect(
        Env.resolveReceiptVerifyEndpoint('', supabaseUrl: 'https://chronospark.supabase.co'),
        'https://chronospark.supabase.co/functions/v1/verify-receipt',
      );
      expect(
        Env.resolveReceiptVerifyEndpoint('', supabaseUrl: '   '),
        'https://chronospark.app/verify-receipt',
      );
    });

    test('privacy policy URL stays on the public HTTPS domain', () {
      expect(Env.privacyPolicyUrl, 'https://chronospark.app/privacy');
    });

    test('AI proxy configuration requires a valid HTTPS endpoint', () {
      expect(Env.resolveIsAiProxyConfigured(''), isFalse);
      expect(Env.resolveIsAiProxyConfigured('http://localhost:8787/ai'), isFalse);
      expect(Env.resolveIsAiProxyConfigured('not-a-url'), isFalse);
      expect(Env.resolveIsAiProxyConfigured('https://chronospark.app/functions/v1/ai'), isTrue);
    });
  });
}
