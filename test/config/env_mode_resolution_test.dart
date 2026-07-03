import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env mode resolution', () {
    test('production requires prod flavor and release mode', () {
      expect(Env.resolveIsProduction('prod', isReleaseMode: true), isTrue);
      expect(Env.resolveIsProduction('prod', isReleaseMode: false), isFalse);
      expect(Env.resolveIsProduction('dev', isReleaseMode: true), isFalse);
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
        isTrue,
      );
    });
  });
}
