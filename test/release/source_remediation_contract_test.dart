import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final Directory root = Directory.current;

  String read(String path) =>
      File.fromUri(root.uri.resolve(path)).readAsStringSync();

  test('AI reporting is authenticated, bounded, and configured', () {
    final String service = read(
      'lib/data/services/ai/ai_content_report_service.dart',
    );
    final String function = read('supabase/functions/ai-report/index.ts');
    final String config = read('supabase/config.toml');
    final String migration = read(
      'supabase/migrations/20260817214812_ai_content_reports.sql',
    );

    expect(service, contains("substring(0, 4000)"));
    expect(service, contains(r"'Authorization': 'Bearer $accessToken'"));
    expect(function, contains('/auth/v1/user'));
    expect(function, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(function, contains('withinRateLimit'));
    expect(config, contains('[functions.ai-report]'));
    expect(config, contains('verify_jwt = true'));
    expect(migration, contains('enable row level security'));
    expect(
      migration,
      contains('revoke all on table public.ai_content_reports'),
    );
  });

  test('startup does not request push permission; explicit flow does', () {
    final String source = read(
      'lib/system/firebase/firebase_messaging_bootstrap.dart',
    );
    final int initializer = source.indexOf('Future<String?> _initializeOnce()');
    final int explicit = source.indexOf('requestPermissionAndToken');
    expect(initializer, greaterThanOrEqualTo(0));
    expect(explicit, greaterThan(initializer));
    final int initializerEnd = source.indexOf('\n  }', initializer);
    final String initializerBody = source.substring(
      initializer,
      initializerEnd,
    );
    expect(initializerBody, isNot(contains('requestPermission')));
    expect(source.substring(explicit), contains('requestPermission('));
  });

  test('published policy copies identify one current data contract', () {
    final String policy = read('privacy.html');
    final String bundled = read('assets/legal/privacy_policy.txt');
    expect(policy, contains('GhostHeart5 Supabase project'));
    expect(policy, contains('report a generated response'));
    expect(policy, contains('Settings &gt; Account'));
    expect(bundled, contains('support@chronospark.app'));
    expect(bundled, contains('only that response and your selected reason'));
    expect(
      bundled.toLowerCase(),
      isNot(
        contains(
          'fo'
          'cus session',
        ),
      ),
    );
    expect(bundled.toLowerCase(), isNot(contains('session data')));
  });

  test('OAuth fallback uses the app callback scheme', () {
    final String endpoints = read('lib/config/src/service_endpoints.dart');
    expect(endpoints, contains("defaultValue: 'chronospark://auth-callback'"));
  });

  test('local dotenv is compile-time input and never a Flutter asset', () {
    final YamlMap pubspec = loadYaml(read('pubspec.yaml')) as YamlMap;
    final YamlMap flutter = pubspec['flutter'] as YamlMap;
    final YamlList assets = flutter['assets'] as YamlList;
    final RegExp dotenvAsset = RegExp(r'(^|[\\/])\.env(?:\..+)?$');

    final Iterable<String> assetPaths = assets.map((dynamic asset) {
      if (asset is String) {
        return asset;
      }
      if (asset is YamlMap) {
        return asset['path']?.toString() ?? '';
      }
      return '';
    });
    expect(assetPaths.where(dotenvAsset.hasMatch), isEmpty);

    expect(
      read('lib/app/startup/app_bootstrap.dart'),
      isNot(contains('flutter_dotenv')),
    );
    expect(
      read('lib/app/startup/startup_error_hooks.dart'),
      isNot(contains('dotenv.load')),
    );
    expect(
      read('.vscode/launch.json'),
      contains('--dart-define-from-file=.env'),
    );
    expect(
      read('scripts/flutter_windows_run_local_nuget.ps1'),
      contains('--dart-define-from-file=.env'),
    );
  });
}
