import 'dart:convert';

import 'package:fantastic_guacamole/config/app_flavor.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const bool _qaDefinesProvided =
    bool.hasEnvironment('CHRONOSPARK_APP_FLAVOR') &&
    bool.hasEnvironment('CHRONOSPARK_ENABLE_MOCK_LOGIN') &&
    bool.hasEnvironment('CHRONOSPARK_ENABLE_MOCK_MODE') &&
    bool.hasEnvironment('CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS') &&
    bool.hasEnvironment('CHRONOSPARK_PAYWALL_DISABLED');

String _legacySupabaseKey({String? role, Object? payload}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(<String, String>{'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode(payload ?? <String, Object?>{'role': role, 'iss': 'supabase'})}.'
      'contract-signature';
}

void main() {
  group('Env mode resolution', () {
    test('release configuration ignores bundled dotenv values', () {
      expect(
        Env.resolveConfiguredString(
          defineValue: 'https://release.example.com',
          defineProvided: false,
          dotenvValue: 'https://local.example.com',
          isReleaseMode: true,
        ),
        'https://release.example.com',
      );
      expect(
        Env.resolveConfiguredBool(
          key: 'CHRONOSPARK_ENABLE_ANALYTICS',
          defineValue: true,
          defineProvided: false,
          rawDefineValue: null,
          dotenvValue: 'false',
          isReleaseMode: true,
        ),
        isTrue,
      );
    });

    test('explicit defines override dotenv outside release mode', () {
      expect(
        Env.resolveConfiguredString(
          defineValue: 'defined',
          defineProvided: true,
          dotenvValue: 'local',
          isReleaseMode: false,
        ),
        'defined',
      );
      expect(
        Env.resolveConfiguredBool(
          key: 'CHRONOSPARK_ENABLE_ANALYTICS',
          defineValue: false,
          defineProvided: true,
          rawDefineValue: 'false',
          dotenvValue: 'true',
          isReleaseMode: false,
        ),
        isFalse,
      );
    });

    test('dotenv remains a local fallback when no define is provided', () {
      expect(
        Env.resolveConfiguredString(
          defineValue: 'default',
          defineProvided: false,
          dotenvValue: '  local  ',
          isReleaseMode: false,
        ),
        'local',
      );
      expect(
        Env.resolveConfiguredBool(
          key: 'CHRONOSPARK_ENABLE_ANALYTICS',
          defineValue: false,
          defineProvided: false,
          rawDefineValue: null,
          dotenvValue: 'yes',
          isReleaseMode: false,
        ),
        isTrue,
      );
    });

    test('accepted boolean spellings resolve deterministically', () {
      const Map<String, bool> values = <String, bool>{
        'true': true,
        '1': true,
        'yes': true,
        'on': true,
        'false': false,
        '0': false,
        'no': false,
        'off': false,
      };

      for (final MapEntry<String, bool> entry in values.entries) {
        expect(
          Env.resolveConfiguredBool(
            key: 'CHRONOSPARK_ENABLE_ANALYTICS',
            defineValue: !entry.value,
            defineProvided: false,
            rawDefineValue: null,
            dotenvValue: entry.key,
            isReleaseMode: false,
          ),
          entry.value,
          reason: 'boolean spelling "${entry.key}"',
        );
      }
    });

    test('malformed boolean configuration is rejected explicitly', () {
      expect(
        () => Env.resolveConfiguredBool(
          key: 'CHRONOSPARK_ENABLE_ANALYTICS',
          defineValue: true,
          defineProvided: false,
          rawDefineValue: null,
          dotenvValue: 'sometimes',
          isReleaseMode: false,
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException error) => error.message,
            'message',
            contains('CHRONOSPARK_ENABLE_ANALYTICS'),
          ),
        ),
      );
      expect(
        () => Env.resolveConfiguredBool(
          key: 'CHRONOSPARK_ENABLE_ANALYTICS',
          defineValue: true,
          defineProvided: true,
          rawDefineValue: null,
          dotenvValue: 'false',
          isReleaseMode: true,
        ),
        throwsFormatException,
      );
      expect(
        () => Env.resolveConfiguredBool(
          key: 'CHRONOSPARK_ENABLE_ANALYTICS',
          defineValue: true,
          defineProvided: true,
          rawDefineValue: 'sometimes',
          dotenvValue: 'false',
          isReleaseMode: true,
        ),
        throwsFormatException,
      );
      expect(
        Env.resolveConfiguredBool(
          key: 'CHRONOSPARK_ENABLE_ANALYTICS',
          defineValue: true,
          defineProvided: false,
          rawDefineValue: null,
          dotenvValue: 'sometimes',
          isReleaseMode: true,
        ),
        isTrue,
        reason: 'release builds must continue ignoring bundled dotenv values',
      );
    });

    test('production security rules require release mode and prod flavor', () {
      expect(Env.resolveIsProduction('prod', isReleaseMode: true), isTrue);
      expect(Env.resolveIsProduction('prod', isReleaseMode: false), isFalse);
      expect(Env.resolveIsProduction('dev', isReleaseMode: true), isFalse);
      expect(Env.resolveIsProduction('qa', isReleaseMode: true), isFalse);
    });

    test(
      'mock mode is enabled only in non-production when explicitly enabled',
      () {
        expect(
          Env.resolveIsMockMode(isProduction: false, enableMockMode: true),
          isTrue,
        );
        expect(
          Env.resolveIsMockMode(isProduction: false, enableMockMode: false),
          isFalse,
        );
        expect(
          Env.resolveIsMockMode(isProduction: true, enableMockMode: true),
          isFalse,
        );
      },
    );

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

    test(
      'mock login is opt-in in non-production and always blocked in production',
      () {
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
          Env.resolveIsMockLoginEnabled(
            isProduction: true,
            isMockMode: false,
            enableMockLogin: true,
          ),
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
      },
    );

    test('tester full access remains production-safe', () {
      expect(
        Env.resolveHasTesterFullAccess(
          isProduction: true,
          enableTesterFullAccess: false,
        ),
        isFalse,
      );
      expect(
        Env.resolveHasTesterFullAccess(
          isProduction: false,
          enableTesterFullAccess: false,
        ),
        isFalse,
      );
      expect(
        Env.resolveHasTesterFullAccess(
          isProduction: false,
          enableTesterFullAccess: true,
        ),
        isTrue,
      );
    });

    test(
      'explicit QA defines take precedence over a local dotenv fixture',
      () {
        dotenv.loadFromString(
          envString: '''
CHRONOSPARK_APP_FLAVOR=prod
CHRONOSPARK_ENABLE_MOCK_LOGIN=false
CHRONOSPARK_ENABLE_MOCK_MODE=false
CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS=false
CHRONOSPARK_PAYWALL_DISABLED=false
''',
        );

        expect(Env.appFlavor, 'qa');
        expect(Env.flavor, AppFlavor.qualityAssurance);
        expect(Env.enableMockLogin, isTrue);
        expect(Env.enableMockMode, isTrue);
        expect(Env.enableTesterFullAccess, isTrue);
        expect(Env.enablePaywallDisabled, isTrue);
        expect(Env.isMockMode, isTrue);
        expect(Env.hasTesterFullAccess, isTrue);
        expect(Env.isMockLoginEnabled, isTrue);
      },
      skip: _qaDefinesProvided
          ? false
          : 'Run with --dart-define-from-file=tool/qa_defines.json.',
    );

    test('receipt verification endpoint derives from configuration safely', () {
      expect(
        Env.resolveReceiptVerifyEndpoint(
          'https://billing.chronospark.app/verify-receipt',
          supabaseUrl: 'https://ignored.example.supabase.co',
        ),
        'https://billing.chronospark.app/verify-receipt',
      );
      expect(
        Env.resolveReceiptVerifyEndpoint(
          '',
          supabaseUrl: 'https://chronospark.supabase.co',
        ),
        'https://chronospark.supabase.co/functions/v1/verify-receipt',
      );
      expect(Env.resolveReceiptVerifyEndpoint('', supabaseUrl: '   '), isEmpty);
    });

    test('backend configuration requires a secure root URL and valid key', () {
      final String legacyKey = _legacySupabaseKey(role: 'anon');
      const String publishableKey = 'sb_publishable_123456789012345678901234';

      expect(
        Env.resolveIsSupabaseConfigured(
          url: 'https://project.supabase.co',
          anonKey: legacyKey,
        ),
        isTrue,
      );
      expect(
        Env.resolveIsSupabaseConfigured(
          url: 'https://project.supabase.co/',
          anonKey: publishableKey,
        ),
        isTrue,
      );
      expect(
        Env.resolveIsSupabaseConfigured(
          url: 'http://project.supabase.co',
          anonKey: legacyKey,
        ),
        isFalse,
      );
      expect(
        Env.resolveIsSupabaseConfigured(
          url: 'https://user:password@project.supabase.co',
          anonKey: legacyKey,
        ),
        isFalse,
      );
      expect(
        Env.resolveIsSupabaseConfigured(
          url: 'https://project.supabase.co/rest/v1',
          anonKey: legacyKey,
        ),
        isFalse,
      );
      expect(
        Env.resolveIsSupabaseConfigured(
          url: 'https://project.supabase.co',
          anonKey: 'YOUR_SUPABASE_ANON_KEY',
        ),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey(
          _legacySupabaseKey(role: 'service_role'),
        ),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey(
          _legacySupabaseKey(role: 'authenticated'),
        ),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey(_legacySupabaseKey(role: 'ANON')),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey(
          _legacySupabaseKey(payload: <String, String>{'iss': 'supabase'}),
        ),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey(
          _legacySupabaseKey(payload: <String, Object>{'role': true}),
        ),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey('valid-header.a.contract-signature'),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey('valid-header.ew.contract-signature'),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey('valid-header..contract-signature'),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey(
          'valid-header.valid-payload.contract-signature.extra',
        ),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey(
          'sb_secret_123456789012345678901234567890',
        ),
        isFalse,
      );
      expect(
        Env.resolveIsValidSupabaseAnonKey(
          'sb_publishable_12345678901234567890!',
        ),
        isFalse,
      );
    });

    test('AI report endpoint derives only from valid configuration', () {
      expect(
        Env.resolveAiReportEndpoint(
          '',
          supabaseUrl: 'https://project.supabase.co',
        ),
        'https://project.supabase.co/functions/v1/ai-report',
      );
      expect(
        Env.resolveAiReportEndpoint(
          '',
          supabaseUrl: 'https://user:password@project.supabase.co',
        ),
        isEmpty,
      );
      expect(
        Env.resolveAiReportEndpoint(
          'https://project.supabase.co/functions/v1/ai-report',
          supabaseUrl: 'https://project.supabase.co',
        ),
        'https://project.supabase.co/functions/v1/ai-report',
      );
      for (final String hostile in <String>[
        'https://attacker.example/functions/v1/ai-report',
        'https://project.supabase.co:8443/functions/v1/ai-report',
        'https://user:password@project.supabase.co/functions/v1/ai-report',
        'https://project.supabase.co/functions/v1/ai-report/',
        'https://project.supabase.co/functions/v1/ai-report?redirect=evil',
        'https://project.supabase.co/functions/v1/ai-report#token',
        'https://project.supabase.co/functions/v1/ai-report/other',
      ]) {
        expect(
          Env.resolveAiReportEndpoint(
            hostile,
            supabaseUrl: 'https://project.supabase.co',
          ),
          isEmpty,
          reason: hostile,
        );
      }
    });

    test('AI proxy configuration requires a valid HTTPS endpoint', () {
      expect(Env.resolveIsAiProxyConfigured(''), isFalse);
      expect(
        Env.resolveIsAiProxyConfigured('http://localhost:8787/ai'),
        isFalse,
      );
      expect(Env.resolveIsAiProxyConfigured('not-a-url'), isFalse);
      expect(
        Env.resolveIsAiProxyConfigured(
          'https://user:password@chronospark.app/functions/v1/ai',
        ),
        isFalse,
      );
      expect(
        Env.resolveIsAiProxyConfigured(
          'https://chronospark.app/functions/v1/ai?token=secret',
        ),
        isFalse,
      );
      expect(
        Env.resolveIsAiProxyConfigured(
          'https://chronospark.app/functions/v1/ai#fragment',
        ),
        isFalse,
      );
      expect(
        Env.resolveIsAiProxyConfigured(
          'https://chronospark.app/functions/v1/ai',
        ),
        isTrue,
      );
    });
  });
}
