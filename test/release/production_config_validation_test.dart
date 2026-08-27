import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/validate_production_config.dart';

void main() {
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
      'project_id': 'chronospark-production',
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
}
