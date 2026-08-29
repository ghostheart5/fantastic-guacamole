import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QA mock profile cannot contact production-facing services', () {
    final Map<String, dynamic> defines =
        jsonDecode(File('tool/qa_defines.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(defines['CHRONOSPARK_APP_FLAVOR'], 'qa');
    expect(defines['CHRONOSPARK_ENABLE_MOCK_LOGIN'], isTrue);
    expect(defines['CHRONOSPARK_ENABLE_MOCK_MODE'], isTrue);
    expect(defines['CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS'], isTrue);
    expect(defines['CHRONOSPARK_PAYWALL_DISABLED'], isTrue);
    expect(defines['CHRONOSPARK_ENABLE_CLOUD_SYNC'], isFalse);
    expect(defines['CHRONOSPARK_ENABLE_ANALYTICS'], isFalse);
    expect(defines['CHRONOSPARK_ENABLE_CRASH_REPORTING'], isFalse);
    expect(defines['CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS'], isFalse);
    expect(defines.containsKey('CHRONOSPARK_MOCK_LOGIN_EMAIL'), isFalse);
    expect(defines.containsKey('CHRONOSPARK_MOCK_LOGIN_PASSWORD'), isFalse);
    for (final String key in <String>[
      'CHRONOSPARK_SUPABASE_URL',
      'CHRONOSPARK_SUPABASE_ANON_KEY',
      'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
      'CHRONOSPARK_AI_PROXY_ENDPOINT',
      'CHRONOSPARK_AI_REPORT_ENDPOINT',
      'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
    ]) {
      expect(defines.containsKey(key), isFalse, reason: key);
    }
  });

  test('every QA build entry point consumes the isolated profile', () {
    final List<String> entryPoints = <String>[
      File('tool/build_tester.ps1').readAsStringSync(),
      File('scripts/build_android_aab_tester_guarded.ps1').readAsStringSync(),
      File('scripts/run_maestro_android_evidence.ps1').readAsStringSync(),
    ];

    for (final String source in entryPoints) {
      expect(source, contains('--dart-define-from-file=tool/qa_defines.json'));
    }

    final String guardedBuild = entryPoints[1];
    expect(guardedBuild, isNot(contains("Join-Path \$repoRoot '.env'")));
    for (final String key in <String>[
      'CHRONOSPARK_ENABLE_CLOUD_SYNC',
      'CHRONOSPARK_ENABLE_ANALYTICS',
      'CHRONOSPARK_ENABLE_CRASH_REPORTING',
      'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS',
      'CHRONOSPARK_SUPABASE_URL',
      'CHRONOSPARK_SUPABASE_ANON_KEY',
      'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
      'CHRONOSPARK_AI_PROXY_ENDPOINT',
      'CHRONOSPARK_AI_REPORT_ENDPOINT',
      'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
    ]) {
      expect(guardedBuild, isNot(contains('--dart-define=$key=')), reason: key);
    }
  });

  test('QA tester access is credential-free in app and build entry points', () {
    final String testerBuild = File('tool/build_tester.ps1').readAsStringSync();
    final String guardedBuild = File(
      'scripts/build_android_aab_tester_guarded.ps1',
    ).readAsStringSync();
    final String maestroRunner = File(
      'scripts/run_maestro_android_evidence.ps1',
    ).readAsStringSync();
    final String maestroSignIn = File(
      '.maestro/subflows/sign-in.yaml',
    ).readAsStringSync();
    final String featureFlags = File(
      'lib/config/src/feature_flags.dart',
    ).readAsStringSync();
    final String env = File('lib/config/env.dart').readAsStringSync();
    final String authGate = File(
      'lib/features/auth/screens/auth_gate.dart',
    ).readAsStringSync();

    for (final String key in <String>[
      'CHRONOSPARK_MOCK_LOGIN_EMAIL',
      'CHRONOSPARK_MOCK_LOGIN_PASSWORD',
    ]) {
      for (final String source in <String>[
        testerBuild,
        guardedBuild,
        maestroRunner,
        featureFlags,
        env,
        authGate,
      ]) {
        expect(source, isNot(contains(key)), reason: key);
      }
    }
    expect(authGate, isNot(contains('Mock login:')));
    expect(
      authGate,
      contains('QA tester build uses an isolated local test profile.'),
    );
    expect(maestroSignIn, contains('TESTER ACCESS.*TEST LOGIN'));
    expect(maestroSignIn, contains(r'${MAESTRO_TEST_EMAIL}'));
    expect(maestroSignIn, contains(r'${MAESTRO_TEST_PASSWORD}'));
  });
}
