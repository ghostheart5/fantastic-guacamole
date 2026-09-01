import 'dart:convert';

import 'package:fantastic_guacamole/config/firebase_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../scripts/validate_production_config.dart';

void main() {
  String legacySupabaseKey(String role) {
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return '${encode(<String, String>{'alg': 'HS256', 'typ': 'JWT'})}.'
        '${encode(<String, String>{'role': role, 'iss': 'supabase'})}.'
        'contract-signature';
  }

  Map<String, String> validValues() => <String, String>{
    'CHRONOSPARK_SUPABASE_URL': 'https://project-ref.supabase.co',
    'CHRONOSPARK_SUPABASE_ANON_KEY':
        'sb_publishable_abcdefghijklmnopqrstuvwxyz0123456789',
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT':
        'https://api.chronospark.app/verify-receipt',
    'CHRONOSPARK_AI_PROXY_ENDPOINT': 'https://api.chronospark.app/ai-proxy',
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT':
        'https://api.chronospark.app/account-delete',
    'CHRONOSPARK_ANDROID_SHA256_CERT': List<String>.filled(32, 'AB').join(':'),
    'CHRONOSPARK_IOS_TEAM_ID': 'A1B2C3D4E5',
  };

  String validGoogleServices() => jsonEncode(<String, Object>{
    'project_info': <String, String>{
      'project_number': '1234567890',
      'project_id': FirebaseIdentity.expectedProjectId,
    },
    'client': <Object>[
      <String, Object>{
        'client_info': <String, Object>{
          'android_client_info': <String, String>{
            'package_name': 'com.ghostheart5.chronospark',
          },
        },
        'api_key': <Object>[
          <String, String>{'current_key': 'firebase-browser-key'},
        ],
      },
    ],
  });

  test('accepts semantically valid production configuration', () {
    expect(
      validateProductionConfiguration(
        validValues(),
        googleServicesJson: validGoogleServices(),
      ),
      isEmpty,
    );
  });

  test('Android validation does not require an Apple team ID', () {
    final Map<String, String> values = validValues()
      ..remove('CHRONOSPARK_IOS_TEAM_ID');

    expect(
      validateProductionConfiguration(
        values,
        googleServicesJson: validGoogleServices(),
        target: ProductionTarget.android,
      ),
      isEmpty,
    );
  });

  test('iOS validation does not require an Android certificate', () {
    final Map<String, String> values = validValues()
      ..remove('CHRONOSPARK_ANDROID_SHA256_CERT');

    expect(
      validateProductionConfiguration(values, target: ProductionTarget.ios),
      isEmpty,
    );
  });

  test('rejects placeholders, insecure URLs, and malformed identities', () {
    final Map<String, String> values = validValues()
      ..['CHRONOSPARK_SUPABASE_URL'] = 'http://localhost:54321'
      ..['CHRONOSPARK_SUPABASE_ANON_KEY'] = '<anon-key>'
      ..['CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT'] =
          'https://example.com/verify-receipt'
      ..['CHRONOSPARK_AI_PROXY_ENDPOINT'] =
          'https://api.chronospark.app/verify-receipt'
      ..['CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT'] = 'https://api.chronospark.app'
      ..['CHRONOSPARK_ANDROID_SHA256_CERT'] = 'AA:BB'
      ..['CHRONOSPARK_IOS_TEAM_ID'] = 'bad-team';

    final List<String> failures = validateProductionConfiguration(values);
    expect(failures, isNotEmpty);
    expect(
      failures,
      contains(
        'CHRONOSPARK_SUPABASE_URL contains a placeholder or local-only value.',
      ),
    );
    expect(
      failures,
      contains(
        'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT must identify a non-root service endpoint.',
      ),
    );
    expect(
      failures,
      contains(
        'CHRONOSPARK_ANDROID_SHA256_CERT must contain exactly 32 SHA-256 bytes.',
      ),
    );
    expect(
      failures,
      contains(
        'CHRONOSPARK_IOS_TEAM_ID must be a 10-character Apple team identifier.',
      ),
    );
  });

  test('accepts only the first-party exact AI report function override', () {
    final Map<String, String> exact = validValues()
      ..['CHRONOSPARK_AI_REPORT_ENDPOINT'] =
          'https://project-ref.supabase.co/functions/v1/ai-report';
    expect(validateProductionConfiguration(exact), isEmpty);

    for (final String hostile in <String>[
      'https://attacker.example/functions/v1/ai-report',
      'https://project-ref.supabase.co:8443/functions/v1/ai-report',
      'https://project-ref.supabase.co/functions/v1/ai-report/',
      'https://project-ref.supabase.co/functions/v1/ai-report?redirect=evil',
      'https://project-ref.supabase.co/functions/v1/other',
    ]) {
      final Map<String, String> values = validValues()
        ..['CHRONOSPARK_AI_REPORT_ENDPOINT'] = hostile;
      expect(
        validateProductionConfiguration(values),
        contains(
          'CHRONOSPARK_AI_REPORT_ENDPOINT must be the exact ai-report function '
          'on CHRONOSPARK_SUPABASE_URL.',
        ),
        reason: hostile,
      );
    }
  });

  test('rejects Firebase configuration for another Android package', () {
    final String wrongPackage = validGoogleServices().replaceFirst(
      'com.ghostheart5.chronospark',
      'com.example.chronospark',
    );
    expect(
      validateProductionConfiguration(
        validValues(),
        googleServicesJson: wrongPackage,
      ),
      contains(
        'Android Firebase configuration must include the ChronoSpark package and an API key.',
      ),
    );
  });

  test('rejects Firebase configuration for another project', () {
    final String wrongProject = validGoogleServices().replaceFirst(
      FirebaseIdentity.expectedProjectId,
      'another-firebase-project',
    );

    expect(
      validateProductionConfiguration(
        validValues(),
        googleServicesJson: wrongProject,
      ),
      contains(
        'Android Firebase configuration must use the expected ChronoSpark project.',
      ),
    );
  });

  test('rejects Firebase configuration without a project ID', () {
    final Map<String, dynamic> missingProject =
        jsonDecode(validGoogleServices()) as Map<String, dynamic>;
    final Map<String, dynamic> projectInfo =
        missingProject['project_info'] as Map<String, dynamic>;
    projectInfo.remove('project_id');

    expect(
      validateProductionConfiguration(
        validValues(),
        googleServicesJson: jsonEncode(missingProject),
      ),
      contains(
        'Android Firebase configuration must identify a Firebase project.',
      ),
    );
  });

  test('rejects a privileged legacy Supabase JWT client key', () {
    final Map<String, String> values = validValues()
      ..['CHRONOSPARK_SUPABASE_ANON_KEY'] = legacySupabaseKey('service_role');

    expect(
      validateProductionConfiguration(
        values,
        googleServicesJson: validGoogleServices(),
      ),
      contains(
        'CHRONOSPARK_SUPABASE_ANON_KEY must be a Supabase anon JWT or publishable key.',
      ),
    );
  });
}
