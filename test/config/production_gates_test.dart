import 'package:fantastic_guacamole/config/app_flavor.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the mock-auth fail-open defect.
///
/// The gates these cover are what stop a shipped build from selecting
/// MockAuthService (accepts any password) or AlwaysAuthenticatedAuthService
/// (no credentials at all).
void main() {
  group('AppFlavor.tryParse is strict', () {
    test('parses every known value', () {
      expect(AppFlavor.tryParse('dev'), AppFlavor.development);
      expect(AppFlavor.tryParse('test'), AppFlavor.testing);
      expect(AppFlavor.tryParse('qa'), AppFlavor.qualityAssurance);
      expect(AppFlavor.tryParse('staging'), AppFlavor.staging);
      expect(AppFlavor.tryParse('prod'), AppFlavor.production);
    });

    test('accepts the natural long spelling of production', () {
      expect(AppFlavor.tryParse('production'), AppFlavor.production);
      expect(AppFlavor.tryParse('  PRODUCTION  '), AppFlavor.production);
    });

    test('returns null for anything unrecognised', () {
      expect(AppFlavor.tryParse(''), isNull);
      expect(AppFlavor.tryParse('   '), isNull);
      expect(AppFlavor.tryParse('prd'), isNull);
      expect(AppFlavor.tryParse('release'), isNull);
      expect(AppFlavor.tryParse('nonsense'), isNull);
    });

    test('parse still degrades to development, for existing callers', () {
      expect(AppFlavor.parse('nonsense'), AppFlavor.development);
    });
  });

  group('Env.resolveFlavor keeps identity aligned with security', () {
    test('preserves every known flavor identity', () {
      expect(
        Env.resolveFlavor('dev', isReleaseMode: true),
        AppFlavor.development,
      );
      expect(Env.resolveFlavor('test', isReleaseMode: true), AppFlavor.testing);
      expect(
        Env.resolveFlavor('qa', isReleaseMode: true),
        AppFlavor.qualityAssurance,
      );
      expect(
        Env.resolveFlavor('staging', isReleaseMode: true),
        AppFlavor.staging,
      );
      expect(
        Env.resolveFlavor('prod', isReleaseMode: true),
        AppFlavor.production,
      );
    });

    test('unknown release identity fails closed to production', () {
      expect(
        Env.resolveFlavor('nonsense', isReleaseMode: true),
        AppFlavor.production,
      );
      expect(Env.resolveFlavor('', isReleaseMode: true), AppFlavor.production);
    });

    test('unknown non-release identity remains development', () {
      expect(
        Env.resolveFlavor('nonsense', isReleaseMode: false),
        AppFlavor.development,
      );
    });
  });

  group('resolveIsProduction fails closed', () {
    test('a release build with an unknown flavor is treated as production', () {
      // This is the core inversion: an unrecognized release flavor used to
      // parse to development and silently disable every production gate.
      expect(
        Env.resolveIsProduction('nonsense', isReleaseMode: true),
        isTrue,
        reason: 'unknown flavor in a release build must harden, not soften',
      );
      expect(Env.resolveIsProduction('prd', isReleaseMode: true), isTrue);
      expect(Env.resolveIsProduction('', isReleaseMode: true), isTrue);
    });

    test('"production" now resolves to production in release', () {
      expect(
        Env.resolveIsProduction('production', isReleaseMode: true),
        isTrue,
      );
      expect(Env.resolveIsProduction('prod', isReleaseMode: true), isTrue);
    });

    test('non-production flavors stay non-production in release', () {
      expect(Env.resolveIsProduction('dev', isReleaseMode: true), isFalse);
      expect(Env.resolveIsProduction('staging', isReleaseMode: true), isFalse);
      expect(Env.resolveIsProduction('qa', isReleaseMode: true), isFalse);
    });

    test('a debug build is never production, whatever the flavor', () {
      for (final String flavor in <String>[
        'prod',
        'production',
        'dev',
        'nonsense',
        '',
      ]) {
        expect(
          Env.resolveIsProduction(flavor, isReleaseMode: false),
          isFalse,
          reason: 'debug build with flavor "$flavor"',
        );
      }
    });
  });

  group('risk flags are inert in production', () {
    test('mock mode cannot be enabled when isProduction', () {
      expect(
        Env.resolveIsMockMode(isProduction: true, enableMockMode: true),
        isFalse,
      );
    });

    test('mock login cannot be enabled when isProduction', () {
      expect(
        Env.resolveIsMockLoginEnabled(
          isProduction: true,
          isMockMode: true,
          enableMockLogin: true,
        ),
        isFalse,
      );
    });

    test('tester full access cannot be enabled when isProduction', () {
      expect(
        Env.resolveHasTesterFullAccess(
          isProduction: true,
          enableTesterFullAccess: true,
        ),
        isFalse,
      );
    });

    test('paywall cannot be disabled when isProduction', () {
      expect(
        Env.resolveIsPaywallDisabled(
          isProduction: true,
          enablePaywallDisabled: true,
          isMockMode: true,
        ),
        isFalse,
      );
    });

    test('the same flags still work outside production', () {
      expect(
        Env.resolveIsMockLoginEnabled(
          isProduction: false,
          isMockMode: false,
          enableMockLogin: true,
        ),
        isTrue,
      );
      expect(
        Env.resolveIsMockMode(isProduction: false, enableMockMode: true),
        isTrue,
      );
    });
  });

  group('end-to-end: a release build cannot open the mock gates', () {
    test('unknown flavor in release closes mock login and mock mode', () {
      final bool isProduction = Env.resolveIsProduction(
        'prd',
        isReleaseMode: true,
      );
      expect(isProduction, isTrue);

      // Even with every risk flag forced on, production wins.
      final bool mockMode = Env.resolveIsMockMode(
        isProduction: isProduction,
        enableMockMode: true,
      );
      expect(mockMode, isFalse);
      expect(
        Env.resolveIsMockLoginEnabled(
          isProduction: isProduction,
          isMockMode: mockMode,
          enableMockLogin: true,
        ),
        isFalse,
      );
    });
  });
}
