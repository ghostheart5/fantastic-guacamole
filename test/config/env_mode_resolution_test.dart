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

    test('mock login and tester access remain production-safe', () {
      expect(
        Env.resolveIsMockLoginEnabled(
          isProduction: true,
          isMockMode: false,
          enableMockLogin: false,
        ),
        isFalse,
      );
      expect(
        Env.resolveIsMockLoginEnabled(
          isProduction: false,
          isMockMode: false,
          enableMockLogin: false,
        ),
        isTrue,
      );
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
